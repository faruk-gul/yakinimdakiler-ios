import CoreLocation
import MapKit
import SwiftUI

enum PlaceCategory: String, CaseIterable, Identifiable {
    case hospital
    case gasStation
    case market
    case pharmacy
    case taxiStand
    case policeStation

    var id: Self { self }

    var title: String {
        switch self {
        case .hospital:
            return "Hastane"
        case .gasStation:
            return "Benzin"
        case .market:
            return "Market"
        case .pharmacy:
            return "Eczane"
        case .taxiStand:
            return "Taksi"
        case .policeStation:
            return "Polis"
        }
    }

    var pluralTitle: String {
        switch self {
        case .hospital:
            return "Hastaneler"
        case .gasStation:
            return "Benzin Istasyonlari"
        case .market:
            return "Marketler"
        case .pharmacy:
            return "Eczaneler"
        case .taxiStand:
            return "Taksi Duraklari"
        case .policeStation:
            return "Polis Merkezleri"
        }
    }

    var searchQuery: String {
        switch self {
        case .hospital:
            return "Hospital"
        case .gasStation:
            return "Gas Station"
        case .market:
            return "Market"
        case .pharmacy:
            return "Pharmacy"
        case .taxiStand:
            return "Taxi Stand"
        case .policeStation:
            return "Police Station"
        }
    }

    var systemImage: String {
        switch self {
        case .hospital:
            return "cross.case.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .market:
            return "cart.fill"
        case .pharmacy:
            return "pills.fill"
        case .taxiStand:
            return "car.side.fill"
        case .policeStation:
            return "shield.lefthalf.filled"
        }
    }

    var accentColor: Color {
        switch self {
        case .hospital:
            return .red
        case .gasStation:
            return .orange
        case .market:
            return .green
        case .pharmacy:
            return .mint
        case .taxiStand:
            return .yellow
        case .policeStation:
            return .indigo
        }
    }

    var locationPermissionMessage: String {
        "\(pluralTitle.lowercased()) gosterebilmek icin konum erisimi gerekiyor."
    }

    func emptyStateMessage(within radiusInKilometers: Int) -> String {
        "\(radiusInKilometers) km icinde \(pluralTitle.lowercased()) bulunamadi."
    }

    func loadErrorMessage() -> String {
        "\(pluralTitle) yuklenemedi. Lutfen tekrar deneyin."
    }

    func routeErrorMessage() -> String {
        "Bu \(title.lowercased()) icin rota hesaplanamadi."
    }
}

struct NearbyPlace: Identifiable, Hashable {
    let id = UUID()
    let mapItem: MKMapItem
    let distanceMeters: CLLocationDistance

    var name: String {
        mapItem.name ?? "Yer"
    }

    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }

    var address: String {
        let placemark = mapItem.placemark
        let parts = [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }

        return parts.isEmpty ? "Adres bilgisi yok" : parts.joined(separator: ", ")
    }

    var distanceText: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters.rounded())) m"
        }

        return String(format: "%.1f km", distanceMeters / 1000)
    }
}

@MainActor
final class HospitalFinderViewModel: ObservableObject {
    @Published var places: [NearbyPlace] = []
    @Published var selectedPlace: NearbyPlace?
    @Published var selectedCategory: PlaceCategory = .hospital
    @Published var route: MKRoute?
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var isLoading = false
    @Published var errorMessage: String?

    let searchRadius: CLLocationDistance = 5_000

    func refreshPlaces(around location: CLLocation, category: PlaceCategory? = nil) async {
        let category = category ?? selectedCategory

        selectedCategory = category
        isLoading = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: searchRadius * 2.2,
            longitudinalMeters: searchRadius * 2.2
        )
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            let filteredPlaces = response.mapItems
                .map { item in
                    NearbyPlace(
                        mapItem: item,
                        distanceMeters: item.placemark.location?.distance(from: location) ?? .greatestFiniteMagnitude
                    )
                }
                .filter { $0.distanceMeters <= searchRadius }
                .sorted { $0.distanceMeters < $1.distanceMeters }

            places = filteredPlaces
            selectedPlace = filteredPlaces.first
            route = nil
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: searchRadius * 2.6,
                    longitudinalMeters: searchRadius * 2.6
                )
            )

            if filteredPlaces.isEmpty {
                errorMessage = category.emptyStateMessage(within: Int(searchRadius / 1000))
            } else if let firstPlace = filteredPlaces.first {
                await fetchRoute(from: location, to: firstPlace, category: category)
            }
        } catch {
            places = []
            route = nil
            errorMessage = category.loadErrorMessage()
        }

        isLoading = false
    }

    func selectPlace(_ place: NearbyPlace, userLocation: CLLocation?) async {
        selectedPlace = place
        route = nil

        guard let userLocation else {
            cameraPosition = .region(
                MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
            )
            return
        }

        await fetchRoute(from: userLocation, to: place, category: selectedCategory)
    }

    func openDirectionsInMaps() {
        guard let selectedPlace else { return }
        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), selectedPlace.mapItem],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }

    private func fetchRoute(from location: CLLocation, to place: NearbyPlace, category: PlaceCategory) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = place.mapItem
        request.transportType = .automobile

        do {
            let routeResponse = try await MKDirections(request: request).calculate()
            route = routeResponse.routes.first

            if let route {
                let paddedRect = route.polyline.boundingMapRect.insetBy(dx: -1800, dy: -1800)
                cameraPosition = .rect(paddedRect)
            } else {
                cameraPosition = .region(
                    MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
                )
            }
        } catch {
            route = nil
            cameraPosition = .region(
                MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
            )
            errorMessage = category.routeErrorMessage()
        }
    }
}
