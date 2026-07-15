import Foundation
import Observation

@Observable
class AppSettings {
    static let shared = AppSettings()

    var host: String = "127.0.0.1" {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    var port: Int = 8090 {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    var useAuth: Bool = false {
        didSet { UserDefaults.standard.set(useAuth, forKey: "useAuth") }
    }
    var authLogin: String = "" {
        didSet { UserDefaults.standard.set(authLogin, forKey: "authLogin") }
    }
    var authPassword: String = "" {
        didSet { UserDefaults.standard.set(authPassword, forKey: "authPassword") }
    }
    var preferredPlayerPath: String = "" {
        didSet { UserDefaults.standard.set(preferredPlayerPath, forKey: "preferredPlayerPath") }
    }

    var baseURL: String { "http://\(host):\(port)" }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "host") { host = saved }
        let p = UserDefaults.standard.integer(forKey: "port"); if p > 0 { port = p }
        useAuth = UserDefaults.standard.bool(forKey: "useAuth")
        authLogin = UserDefaults.standard.string(forKey: "authLogin") ?? ""
        authPassword = UserDefaults.standard.string(forKey: "authPassword") ?? ""
        preferredPlayerPath = UserDefaults.standard.string(forKey: "preferredPlayerPath") ?? ""
    }
}
