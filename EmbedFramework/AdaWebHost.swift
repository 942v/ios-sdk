//
//  AdaWebHost.swift
//  AdaSDK
//
//  Created by Aaron Vegh on 2019-05-14.
//  Copyright © 2019 Aaron Vegh. All rights reserved.
//

import Foundation
import WebKit

public class AdaWebHost: NSObject {
    
    /// These seem to be per-application options; can they be configured
    /// at the app level instead of requiring a lengthy init process?
    public var handle = "nic"
    public var cluster = ""
    public var language = ""
    public var styles = ""
    public var greeting = ""
    
    /// Provide the host script as a separate file for cleanliness
    private lazy var scriptSource: String = {
        do {
            let bundle = Bundle(for: AdaWebHost.self)
            guard let sourcePath = bundle.path(forResource: "AdaEmbed", ofType: "html") else { return "" }
            return try String(contentsOfFile: sourcePath)
        } catch {
            return ""
        }
    }()
    
    /// Here's where we do our business
    private let webView: WKWebView
    
    /// And here's a view controller to host it
    private var webViewController: AdaWebHostViewController?
    
    /// Let's figure out which of those properties above need to be sent
    /// to this initialization method
    /// Alternative: init(withCustomerId: String) and we look up these properties
    public override init() {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: configuration)
        
        super.init()
        
        userContentController.add(self, name: "embedReady")
        webView.loadHTMLString(scriptSource, baseURL: nil)
    }
    
    /// Push a dictionary of fields to the server
    public func setMetaFields(_ fields: [String: Any]) {
        let serializedData = try! JSONSerialization.data(withJSONObject: fields, options: [])
        let encodedData = serializedData.base64EncodedString()
        let toRun = "setMetaFields('\(encodedData)');"
        
        self.evalJS(toRun)
    }
    
    public func launchWebSupport(from viewController: UIViewController) {
        let webNavController = AdaWebHostViewController.create(with: webView)
        viewController.present(webNavController, animated: true, completion: {
            self.webView.reload()
        })
    }
    
}

extension AdaWebHost: WKScriptMessageHandler {
    /// When the webview loads up, it'll pass back a message to here.
    /// Fire our initialize methods when that happens.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("PM: \(message.name), \(message.body) ")
        if message.name == "embedReady" {
            self.initializeWebView()
        }
    }
}

extension AdaWebHost {
    private func initializeWebView() {
        do {
            let dictionaryData = [
                "handle": self.handle,
                "cluster": self.cluster,
                "language": self.language,
                "styles": self.styles,
                "greeting": self.greeting
                ] as [String : Any]
            let serializedData = try JSONSerialization.data(withJSONObject: dictionaryData, options: [])
            let encodedData = serializedData.base64EncodedString()
            evalJS("initializeEmbed('\(encodedData)');")
        } catch (let error) {
            print("Serialization error: \(error.localizedDescription)")
            return
        }
    }
    
    private func evalJS(_ toRun: String) {
        webView.evaluateJavaScript(toRun) { (result, error) in
            if let err = error {
                print(err)
                print(err.localizedDescription)
            } else {
                guard let dataValue = result else { return }
                print(dataValue)
            }
        }
    }
    
}
