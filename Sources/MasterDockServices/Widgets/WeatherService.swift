import Foundation
import Combine

public struct WeatherInfo: Equatable, Sendable {
    public let temperature: Int
    public let condition: String
    public let locationName: String
    public let highTemp: Int
    public let lowTemp: Int
    public let iconSystemName: String
    
    public init(
        temperature: Int = 72,
        condition: String = "Partly Cloudy",
        locationName: String = "Cupertino",
        highTemp: Int = 78,
        lowTemp: Int = 58,
        iconSystemName: String = "cloud.sun.fill"
    ) {
        self.temperature = temperature
        self.condition = condition
        self.locationName = locationName
        self.highTemp = highTemp
        self.lowTemp = lowTemp
        self.iconSystemName = iconSystemName
    }
}

public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()
    
    @Published public private(set) var currentWeather: WeatherInfo = WeatherInfo()
    
    public init() {
        fetchWeather()
    }
    
    public func fetchWeather() {
        // Fetch weather from lightweight public weather API (Open-Meteo) asynchronously
        Task {
            guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=37.7749&longitude=-122.4194&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&timezone=auto") else { return }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let temp = current["temperature_2m"] as? Double,
                   let weatherCode = current["weather_code"] as? Int,
                   let daily = json["daily"] as? [String: Any],
                   let maxTemps = daily["temperature_2m_max"] as? [Double],
                   let minTemps = daily["temperature_2m_min"] as? [Double] {
                    
                    let (conditionName, iconName) = self.decodeWeatherCode(weatherCode)
                    let info = WeatherInfo(
                        temperature: Int(temp),
                        condition: conditionName,
                        locationName: "Local Weather",
                        highTemp: Int(maxTemps.first ?? temp + 5),
                        lowTemp: Int(minTemps.first ?? temp - 5),
                        iconSystemName: iconName
                    )
                    
                    await MainActor.run {
                        self.currentWeather = info
                    }
                }
            } catch {
                // Fallback default info already populated
            }
        }
    }
    
    private func decodeWeatherCode(_ code: Int) -> (String, String) {
        switch code {
        case 0:
            return ("Clear Sky", "sun.max.fill")
        case 1, 2:
            return ("Partly Cloudy", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51...67:
            return ("Rain Showers", "cloud.rain.fill")
        case 71...77:
            return ("Snow", "cloud.snow.fill")
        case 95...99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Mostly Sunny", "sun.max.fill")
        }
    }
}
