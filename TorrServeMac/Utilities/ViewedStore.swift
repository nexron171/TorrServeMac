import Foundation
import Observation

@Observable
class ViewedStore {
    static let shared = ViewedStore()

    // torrentHash → Set<fileIndex>
    private var cache: [String: Set<Int>] = [:]

    private init() {}

    func isViewed(hash: String, fileIndex: Int) -> Bool {
        indices(for: hash).contains(fileIndex)
    }

    func toggle(hash: String, fileIndex: Int) {
        var set = indices(for: hash)
        if set.contains(fileIndex) { set.remove(fileIndex) } else { set.insert(fileIndex) }
        apply(hash: hash, set: set)
    }

    func markViewed(hash: String, fileIndex: Int) {
        guard !isViewed(hash: hash, fileIndex: fileIndex) else { return }
        var set = indices(for: hash)
        set.insert(fileIndex)
        apply(hash: hash, set: set)
    }

    func resetAll(hash: String) {
        apply(hash: hash, set: [])
    }

    func viewedCount(hash: String) -> Int {
        indices(for: hash).count
    }

    // MARK: - Private

    private func indices(for hash: String) -> Set<Int> {
        if let cached = cache[hash] { return cached }
        let loaded = Set(UserDefaults.standard.array(forKey: udKey(hash)) as? [Int] ?? [])
        cache[hash] = loaded
        return loaded
    }

    private func apply(hash: String, set: Set<Int>) {
        cache[hash] = set
        UserDefaults.standard.set(Array(set), forKey: udKey(hash))
    }

    private func udKey(_ hash: String) -> String { "viewed_\(hash)" }
}
