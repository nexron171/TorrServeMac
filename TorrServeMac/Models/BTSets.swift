import Foundation

struct BTSets: Codable {
    var cacheSize: Int64?
    var preloadBuffer: Bool?
    var preloadCache: Int?
    var readerReadAHead: Int?

    var useDisk: Bool?
    var torrentsSavePath: String?
    var removeCacheOnDrop: Bool?

    var forceEncrypt: Bool?
    var retrackersMode: Int?
    var torrentDisconnectTimeout: Int?
    var enableDebug: Bool?
    var responsiveMode: Bool?

    var enableDLNA: Bool?
    var friendlyName: String?

    var enableRutorSearch: Bool?

    var enableIPv6: Bool?
    var disableTCP: Bool?
    var disableUTP: Bool?
    var disableUPNP: Bool?
    var disableDHT: Bool?
    var disablePEX: Bool?
    var disableUpload: Bool?

    var downloadRateLimit: Int?
    var uploadRateLimit: Int?
    var connectionsLimit: Int?
    var dhtConnectionLimit: Int?
    var peersListenPort: Int?

    enum CodingKeys: String, CodingKey {
        case cacheSize = "CacheSize"
        case preloadBuffer = "PreloadBuffer"
        case preloadCache = "PreloadCache"
        case readerReadAHead = "ReaderReadAHead"
        case useDisk = "UseDisk"
        case torrentsSavePath = "TorrentsSavePath"
        case removeCacheOnDrop = "RemoveCacheOnDrop"
        case forceEncrypt = "ForceEncrypt"
        case retrackersMode = "RetrackersMode"
        case torrentDisconnectTimeout = "TorrentDisconnectTimeout"
        case enableDebug = "EnableDebug"
        case responsiveMode = "ResponsiveMode"
        case enableDLNA = "EnableDLNA"
        case friendlyName = "FriendlyName"
        case enableRutorSearch = "EnableRutorSearch"
        case enableIPv6 = "EnableIPv6"
        case disableTCP = "DisableTCP"
        case disableUTP = "DisableUTP"
        case disableUPNP = "DisableUPNP"
        case disableDHT = "DisableDHT"
        case disablePEX = "DisablePEX"
        case disableUpload = "DisableUpload"
        case downloadRateLimit = "DownloadRateLimit"
        case uploadRateLimit = "UploadRateLimit"
        case connectionsLimit = "ConnectionsLimit"
        case dhtConnectionLimit = "DhtConnectionLimit"
        case peersListenPort = "PeersListenPort"
    }
}
