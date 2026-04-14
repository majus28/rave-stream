import Foundation

final class DestinationService: ObservableObject {
    @Published var destinations: [Destination] = []

    private let keychain = KeychainService.shared
    private let storageKey = "savedDestinations"

    init() {}

    func loadIfNeeded() {
        if destinations.isEmpty {
            loadDestinations()
        }
    }

    func addDestination(_ destination: Destination) {
        destinations.append(destination)
        saveDestinations()
    }

    func updateDestination(_ destination: Destination) {
        if let index = destinations.firstIndex(where: { $0.id == destination.id }) {
            destinations[index] = destination
            saveDestinations()
        }
    }

    func deleteDestination(id: UUID) {
        destinations.removeAll { $0.id == id }
        keychain.delete(key: "streamKey_\(id.uuidString)")
        saveDestinations()
    }

    func saveStreamKey(_ key: String, for destinationId: UUID) {
        keychain.save(string: key, for: "streamKey_\(destinationId.uuidString)")
    }

    func loadStreamKey(for destinationId: UUID) -> String? {
        keychain.loadString(key: "streamKey_\(destinationId.uuidString)")
    }

    private func saveDestinations() {
        if let data = try? JSONEncoder().encode(destinations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadDestinations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Destination].self, from: data) else {
            return
        }
        destinations = saved
    }
}
