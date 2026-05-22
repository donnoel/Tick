import Foundation

nonisolated struct AutoTickRule: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var projectID: TickProject.ID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var startsOnArrival: Bool
    var stopsOnDeparture: Bool
    var isEnabled: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        projectID: TickProject.ID,
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150,
        startsOnArrival: Bool = true,
        stopsOnDeparture: Bool = true,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.startsOnArrival = startsOnArrival
        self.stopsOnDeparture = stopsOnDeparture
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
