

import Foundation
import FBSDKCoreKit
import FBSDKLoginKit

// All database access should go through this class

class DBHelper {
    
    // The local DB name
    static let databaseName = "deepstyle"
    
    // The remote database URL to sync with.
    static let serverDbURL = NSURL(string: "http://demo.couchbasemobile.com:4984/deepstyle/")!
    
    static let sharedInstance = DBHelper()
    
    var database: CBLDatabase? = nil
    
    init() {
        do {
            try database = CBLManager.sharedInstance().databaseNamed(DBHelper.databaseName)
        }
        catch {
            print("Error initializing database: \(error)")
        }
        CBLManager.enableLogging("SyncVerbose")
    }
    
    func startReplicationFromFacebookToken() throws {
        
        if FBSDKAccessToken.currentAccessToken() == nil {
            throw DBHelperError.FBUserNotLoggedIn
        }
        
        let accessTokenStr = FBSDKAccessToken.currentAccessToken().tokenString
        
        let fbAuthenticator = CBLAuthenticator.facebookAuthenticatorWithToken(accessTokenStr)

        let push = database?.createPushReplication(DBHelper.serverDbURL)
        if push == nil {
            throw DBHelperError.ReplicationInitializationError
        }
        let pull = database?.createPullReplication(DBHelper.serverDbURL)
        if pull == nil {
            throw DBHelperError.ReplicationInitializationError
        }
        pull?.customProperties = ["websocket": false]
        
        let replicators = [push, pull]
        for replicator in replicators {
            replicator?.authenticator = fbAuthenticator
            replicator?.continuous = true
            replicator?.start()
        }
    
    }
    
    func createDeepStyleJob(sourceImage: UIImage, styleImage: UIImage) throws -> DeepStyleJob {
        
        // was getting 413 errors with PNG's, used jpeg with lowest compression possible
        let sourceImageData = UIImageJPEGRepresentation(sourceImage, 0.2)
        let styleImageData = UIImageJPEGRepresentation(styleImage, 0.2)
        
        
        let deepStyleJob:DeepStyleJob = DeepStyleJob(forNewDocumentInDatabase: database!)
        deepStyleJob.state = "READY_TO_PROCESS"
        try deepStyleJob.owner = LoginSession.sharedInstance.getLoggedInUserId()
        deepStyleJob.setValue(DeepStyleJob.docType, ofProperty: "type")
        deepStyleJob.setAttachmentNamed("source_image", withContentType: "image/jpg", content: sourceImageData!)
        deepStyleJob.setAttachmentNamed("style_image", withContentType: "image/jpg", content: styleImageData!)
        try deepStyleJob.save()
        return deepStyleJob
        
    }

    
}

enum DBHelperError: ErrorType {
    case FBUserNotLoggedIn
    case ReplicationInitializationError
}