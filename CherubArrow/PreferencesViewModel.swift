import Foundation
import Combine

/// Drives PreferencesView. All mutations are optimistic (the UI updates
/// immediately) and roll back with an error alert if the server rejects them —
/// e.g. a stock ticker or Polymarket slug that doesn't validate.
final class PreferencesViewModel: ObservableObject {
    @Published var newsSources: [NewsSourceItem] = []
    @Published var instruments: [MarketInstrumentItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    private let client = PreferencesClient()

    func load() {
        isLoading = true
        client.fetchAll { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let snapshot):
                self.newsSources = snapshot.newsSources
                self.instruments = snapshot.instruments
            case .failure(let error):
                self.present(error)
            }
        }
    }

    func instruments(for assetClass: String) -> [MarketInstrumentItem] {
        instruments.filter { $0.assetClass == assetClass }
    }

    /// News sources scoped to a category (stocks/crypto/polymarket), plus the
    /// always-shown general-purpose sources (BBC, NPR, etc.) that aren't tied
    /// to any one asset class.
    func newsSources(for category: String) -> [NewsSourceItem] {
        newsSources.filter { $0.category == category || $0.category == "general" }
    }

    // MARK: - News sources

    func addNewsSource(name: String, rssUrl: String, category: String = "general", completion: @escaping (Bool) -> Void) {
        client.addNewsSource(name: name, rssUrl: rssUrl, category: category) { [weak self] result in
            switch result {
            case .success:
                self?.load()
                completion(true)
            case .failure(let error):
                self?.present(error)
                completion(false)
            }
        }
    }

    func toggleNewsSource(_ item: NewsSourceItem) {
        guard let index = newsSources.firstIndex(where: { $0.id == item.id }) else { return }
        let newValue = !newsSources[index].enabled
        newsSources[index].enabled = newValue
        client.toggleNewsSource(id: item.id, enabled: newValue) { [weak self] result in
            if case .failure(let error) = result {
                self?.newsSources[index].enabled = !newValue
                self?.present(error)
            }
        }
    }

    func removeNewsSource(_ item: NewsSourceItem) {
        newsSources.removeAll { $0.id == item.id }
        client.removeNewsSource(id: item.id) { [weak self] result in
            if case .failure(let error) = result {
                self?.present(error)
                self?.load()
            }
        }
    }

    // MARK: - Market instruments

    func addInstrument(assetClass: String, symbol: String, displayName: String, threshold: Double, completion: @escaping (Bool) -> Void) {
        client.addInstrument(assetClass: assetClass, symbol: symbol, displayName: displayName, moveThresholdPct: threshold) { [weak self] result in
            switch result {
            case .success:
                self?.load()
                completion(true)
            case .failure(let error):
                self?.present(error)
                completion(false)
            }
        }
    }

    func toggleInstrument(_ item: MarketInstrumentItem) {
        guard let index = instruments.firstIndex(where: { $0.id == item.id }) else { return }
        let newValue = !instruments[index].enabled
        instruments[index].enabled = newValue
        client.toggleInstrument(id: item.id, enabled: newValue) { [weak self] result in
            if case .failure(let error) = result {
                self?.instruments[index].enabled = !newValue
                self?.present(error)
            }
        }
    }

    func updateThreshold(_ item: MarketInstrumentItem, to value: Double) {
        guard let index = instruments.firstIndex(where: { $0.id == item.id }) else { return }
        let oldValue = instruments[index].moveThresholdPct
        instruments[index].moveThresholdPct = value
        client.updateThreshold(id: item.id, moveThresholdPct: value) { [weak self] result in
            if case .failure(let error) = result {
                self?.instruments[index].moveThresholdPct = oldValue
                self?.present(error)
            }
        }
    }

    func removeInstrument(_ item: MarketInstrumentItem) {
        instruments.removeAll { $0.id == item.id }
        client.removeInstrument(id: item.id) { [weak self] result in
            if case .failure(let error) = result {
                self?.present(error)
                self?.load()
            }
        }
    }

    private func present(_ error: PreferencesError) {
        errorMessage = error.errorDescription
        showError = true
    }
}
