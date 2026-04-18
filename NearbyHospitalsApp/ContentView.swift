import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = HospitalFinderViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch locationManager.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    mainContent
                case .denied, .restricted:
                    blockedState
                case .notDetermined:
                    loadingState(
                        title: "Konum izni gerekli",
                        message: viewModel.selectedCategory.locationPermissionMessage
                    )
                @unknown default:
                    loadingState(
                        title: "Konum durumu bilinmiyor",
                        message: "Lutfen uygulamayi tekrar acin ve konum izni verin."
                    )
                }
            }
            .navigationTitle("Yakinimdakiler")
        }
        .task {
            locationManager.requestLocationAccess()
        }
        .task(id: locationManager.lastKnownLocation?.timestamp) {
            guard let location = locationManager.lastKnownLocation else { return }
            await viewModel.refreshPlaces(around: location)
        }
        .task(id: viewModel.selectedCategory) {
            guard let location = locationManager.lastKnownLocation else { return }
            await viewModel.refreshPlaces(around: location)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            categoryPicker
            mapCard
            statusBanner
            placesList
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlaceCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(viewModel.selectedCategory == category ? .white : category.accentColor)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(viewModel.selectedCategory == category ? category.accentColor : category.accentColor.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mapCard: some View {
        Map(position: $viewModel.cameraPosition) {
            UserAnnotation()

            ForEach(viewModel.places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.selectedCategory.systemImage)
                            .font(.title2)
                            .foregroundStyle(viewModel.selectedCategory == .taxiStand ? Color.black : Color.white)
                            .padding(8)
                            .background(
                                (place.id == viewModel.selectedPlace?.id ? viewModel.selectedCategory.accentColor : viewModel.selectedCategory.accentColor.opacity(0.82)),
                                in: Circle()
                            )

                        Text(place.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .onTapGesture {
                        Task {
                            await viewModel.selectPlace(place, userLocation: locationManager.lastKnownLocation)
                        }
                    }
                }
            }

            if let route = viewModel.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let selectedPlace = viewModel.selectedPlace {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPlace.name)
                            .font(.headline)
                        Text(selectedPlace.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(selectedPlace.distanceText)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                if let route = viewModel.route {
                    HStack(spacing: 16) {
                        Label(route.expectedTravelTime.formattedTravelTime, systemImage: "car.fill")
                        Label(route.distance.formattedDistance, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.openDirectionsInMaps()
                } label: {
                    Label("Apple Maps ile Navigasyon", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.selectedCategory.accentColor)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let errorMessage = viewModel.errorMessage {
            loadingState(title: "Bilgi", message: errorMessage)
        }
    }

    private var placesList: some View {
        List(viewModel.places) { place in
            Button {
                Task {
                    await viewModel.selectPlace(place, userLocation: locationManager.lastKnownLocation)
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: viewModel.selectedCategory.systemImage)
                        .font(.title2)
                        .foregroundStyle(viewModel.selectedCategory.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .foregroundStyle(.primary)
                        Text(place.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(place.distanceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(place.id == viewModel.selectedPlace?.id ? viewModel.selectedCategory.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
                    .padding(.vertical, 4)
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var blockedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Konum izni kapali")
                .font(.title3.bold())

            Text("Ayarlar > Gizlilik > Konum Servisleri uzerinden bu uygulama icin konum izni verince 5 km icindeki yakin yerleri gosterebiliriz.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Ayarlari Ac") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func loadingState(title: String, message: String) -> some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(title)
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private extension TimeInterval {
    var formattedTravelTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self < 3600 ? [.minute] : [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: self) ?? "--"
    }
}

private extension CLLocationDistance {
    var formattedDistance: String {
        if self < 1000 {
            return "\(Int(self.rounded())) m"
        }

        return String(format: "%.1f km", self / 1000)
    }
}
