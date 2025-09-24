import Foundation

@objc protocol SPTPlayerTrack {
    func setMetadata(_ metadata: [String:String])
    func metadata() -> [String:String]
    func extractedColorHex() -> String?
    func URI() -> SPTURL
    func trackTitle() -> String
    func albumTitle() -> String

    //  EeveeSpotify.hookTarget == .lastAvailableiOS14 ? track.artistTitle() : track.artistName()
    func artistName() -> String
    func artistTitle() -> String
}
