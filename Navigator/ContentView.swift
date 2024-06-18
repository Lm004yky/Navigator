import SwiftUI
import MapKit
import CoreLocation

@main
struct MapNavigatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct IdentifiablePointAnnotation: Identifiable {
    let id = UUID()
    var point: MKPointAnnotation
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var city: String = ""
    @State private var address: String = ""

    var body: some View {
        VStack {
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                annotationItems: viewModel.annotations) { annotation in
                MapAnnotation(coordinate: annotation.point.coordinate) {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2)
                        .background(Circle().foregroundColor(.red.opacity(0.3)))
                        .frame(width: 30, height: 30)
                }
            }
            .overlay(
                Group {
                    if let route = viewModel.routeOverlay {
                        MapRouteOverlay(route: route)
                    }
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    TextField("Enter city", text: $city)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                HStack {
                    TextField("Enter address", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        viewModel.searchInCity(city: city, address: address)
                    }) {
                        Text("Search")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()

                    Button(action: {
                        viewModel.markOnMap(city: city, address: address)
                    }) {
                        Text("Mark on Map")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            
            HStack {
                Button(action: {
                    viewModel.zoomIn()
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding()

                Button(action: {
                    viewModel.zoomOut()
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.checkIfLocationServicesIsEnabled()
        }
    }
}

final class ContentViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                                               span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @Published var annotations: [IdentifiablePointAnnotation] = []
    @Published var routeOverlay: MKPolyline?
    private var locationManager: CLLocationManager?

    override init() {
        super.init()
        checkIfLocationServicesIsEnabled()
    }
    
    func checkIfLocationServicesIsEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager!.delegate = self
            locationManager!.desiredAccuracy = kCLLocationAccuracyBest
            locationManager!.requestWhenInUseAuthorization()
        } else {
            // Handle the case where location services are not enabled
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager!.startUpdatingLocation()
        case .denied, .restricted:
            // Handle the case where location services are denied or restricted
            break
        case .notDetermined:
            locationManager!.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: location.coordinate,
                                             span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle error
    }

    func searchInCity(city: String, address: String) {
        let searchString = "\(address), \(city)"
        getDirections(to: searchString)
    }

    func markOnMap(city: String, address: String) {
        let searchString = "\(address), \(city)"
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchString) { placemarks, error in
            guard let placemark = placemarks?.first, let location = placemark.location else {
                // Handle error
                return
            }
            self.setMapRegion(to: location.coordinate)
        }
    }

    func getDirections(to destination: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destination) { placemarks, error in
            guard let placemark = placemarks?.first, let location = placemark.location else {
                // Handle error
                return
            }
            self.calculateRoute(to: location.coordinate)
        }
    }
    
    func setMapRegion(to coordinate: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: coordinate,
                                             span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            let destinationAnnotation = MKPointAnnotation()
            destinationAnnotation.coordinate = coordinate
            self.annotations = [IdentifiablePointAnnotation(point: destinationAnnotation)]
        }
    }

    func calculateRoute(to destinationCoordinate: CLLocationCoordinate2D) {
        guard let userLocation = locationManager?.location?.coordinate else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                // Handle error
                return
            }
            DispatchQueue.main.async {
                self.routeOverlay = route.polyline
            }
        }
    }

    func zoomIn() {
        DispatchQueue.main.async {
            let span = MKCoordinateSpan(latitudeDelta: self.region.span.latitudeDelta / 2, longitudeDelta: self.region.span.longitudeDelta / 2)
            self.region.span = span
        }
    }

    func zoomOut() {
        DispatchQueue.main.async {
            let span = MKCoordinateSpan(latitudeDelta: self.region.span.latitudeDelta * 2, longitudeDelta: self.region.span.longitudeDelta * 2)
            self.region.span = span
        }
    }
}

struct MapRouteOverlay: UIViewRepresentable {
    var route: MKPolyline

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.addOverlay(route)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlay(route)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapRouteOverlay

        init(_ parent: MapRouteOverlay) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
