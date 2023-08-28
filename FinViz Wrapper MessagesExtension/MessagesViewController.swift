import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController, UISearchBarDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var chartContainerView: UIView! // Changed to UIView
    @IBOutlet weak var dailyButton: UIButton!
    @IBOutlet weak var weeklyButton: UIButton!
    @IBOutlet weak var monthlyButton: UIButton!
    @IBOutlet weak var yearlyButton: UIButton!
    @IBOutlet weak var maxButton: UIButton!
    @IBOutlet weak var relatedTickersTextView: UITextView! // Added UITextView outlet
   
    // Create UIImageView
    let imageView = UIImageView()
    var lastSearchTerm: String = "AAPL"

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        if presentationStyle == .expanded && shouldBecomeFirstResponderAfterTransition {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.searchBar.becomeFirstResponder()
            }
            shouldBecomeFirstResponderAfterTransition = false
        }
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        if presentationStyle == .expanded && shouldBecomeFirstResponderAfterTransition {
            DispatchQueue.main.async {
                self.searchBar.becomeFirstResponder()
            }
            shouldBecomeFirstResponderAfterTransition = false
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
       
        searchBar.delegate = self
       
        // Initialize the tap gesture and add it to chartContainerView
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(chartContainerViewTapped))
        chartContainerView.addGestureRecognizer(tapGesture)
        chartContainerView.isUserInteractionEnabled = true
       
        // Initialize imageView
        imageView.frame = CGRect(x: 10, y: 10, width: chartContainerView.frame.size.width - 20, height: chartContainerView.frame.size.height - 20)
        imageView.contentMode = .scaleAspectFit
        chartContainerView.addSubview(imageView)

        // Call the function with "AAPL" as the argument
        retrieveAndDisplayImage(lastSearchTerm)

        // Configure time range buttons
        dailyButton.addTarget(self, action: #selector(dailyButtonTapped), for: .touchUpInside)
        weeklyButton.addTarget(self, action: #selector(weeklyButtonTapped), for: .touchUpInside)
        monthlyButton.addTarget(self, action: #selector(monthlyButtonTapped), for: .touchUpInside)
        yearlyButton.addTarget(self, action: #selector(yearlyButtonTapped), for: .touchUpInside)
        maxButton.addTarget(self, action: #selector(maxButtonTapped), for: .touchUpInside)

        // Fetch related tickers
        fetchRelatedTickers()
    }
   
    var shouldBecomeFirstResponderAfterTransition = false

    @objc func searchBarTapped() {
        if self.presentationStyle == .compact {
            shouldBecomeFirstResponderAfterTransition = true
            self.requestPresentationStyle(.expanded)
        } else {
            searchBar.becomeFirstResponder()
        }
    }

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        if self.presentationStyle == .compact {
            shouldBecomeFirstResponderAfterTransition = true
            self.requestPresentationStyle(.expanded)
            return false
        }
        return true
    }
   
    @objc func chartContainerViewTapped() {
        // New function to send chart as a message
        if let image = imageView.image {
            if let conversation = activeConversation {
                let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
                let layout = MSMessageTemplateLayout()
                layout.image = image
                message.layout = layout
                conversation.insert(message, completionHandler: nil)
            }
        }
       
        // Request the compact presentation style after sending the chart
        self.requestPresentationStyle(.compact)
    }
   
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let searchTerm = searchBar.text {
            lastSearchTerm = searchTerm
            retrieveAndDisplayImage(searchTerm)
            fetchRelatedTickers()
        }
        searchBar.resignFirstResponder()
    }
   
    func retrieveAndDisplayImage(_ searchTerm: String, timeRange: String = "180", interval: String = "d") {
        // Retrieve the image
        guard let imageUrl = URL(string: "https://www.stockscores.com/chart.asp?TickerSymbol=\(searchTerm)&TimeRange=\(timeRange)&Interval=\(interval)&Volume=None&ChartType=CandleStick&Stockscores=None&ChartWidth=600&ChartHeight=480&LogScale=None&Band=None&avgType1=None&movAvg1=&avgType2=None&movAvg2=&Indicator1=None&Indicator2=None&Indicator3=None&Indicator4=None&endDate=&CompareWith=&entryPrice=&stopLossPrice=&candles=redgreen") else {
            return
        }
       
        let imageTask = URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
        imageTask.resume()
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        if let layout = message.layout as? MSMessageTemplateLayout, let image = layout.image {
            imageView.image = image
        }
    }

    @objc func dailyButtonTapped() {
        retrieveAndDisplayImage(lastSearchTerm, timeRange: "1", interval: "5")
        fetchRelatedTickers()
    }

    @objc func weeklyButtonTapped() {
        retrieveAndDisplayImage(lastSearchTerm, timeRange: "5", interval: "15")
        fetchRelatedTickers()
    }

    @objc func monthlyButtonTapped() {
        retrieveAndDisplayImage(lastSearchTerm, timeRange: "30", interval: "240")
        fetchRelatedTickers()
    }

    @objc func yearlyButtonTapped() {
        retrieveAndDisplayImage(lastSearchTerm, timeRange: "365", interval: "d")
        fetchRelatedTickers()
    }

    @objc func maxButtonTapped() {
        retrieveAndDisplayImage(lastSearchTerm, timeRange: "1825", interval: "w")
        fetchRelatedTickers()
    }

    func fetchRelatedTickers() {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(lastSearchTerm)") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let news = json["news"] as? [[String: Any]] {
                    for item in news {
                        if let relatedTickers = item["relatedTickers"] as? [String] {
                            DispatchQueue.main.async {
                                self.relatedTickersTextView.text = "Related Tickers:\n" + relatedTickers.joined(separator: ", ")
                            }
                        }
                    }
                }
            } catch {
                print("JSON error: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
}

