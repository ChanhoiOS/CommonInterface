//
//  ViewController.swift
//  CommonFunction
//
//  Created by 이찬호 on 2/28/24.
//

import UIKit
import WebKit
import Then
import SnapKit
import SwiftPromises

class ViewController: UIViewController {
    
    var webView: WKWebView!
    let webConfiguration = WKWebViewConfiguration()
    
    private var taskHandlers = [String: TaskHandler]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setContentController()
        setFunction()
        setWebView()
    }
    
    func setContentController() {
        let contentController = WKUserContentController()
        webConfiguration.userContentController = contentController
    }
    
    func setFunction() {
        taskHandlers["outLink"] = { param in
            var result = [String: Any]()
            
            if let url = param["url"] as? String, self.urlInvalid(url) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(URL(string: url)!, options: [:])
                }
                
                result["success"] = true
                return result
            } else {
                do {
                    throw TaskError(message: "Illegal State Error!!")
                } catch {
                    result["success"] = false
                    return result
                }
            }
        }
    }

    func setWebView() {
        webView = WKWebView(frame: self.view.frame, configuration: webConfiguration)
        
        taskHandlers.keys.forEach {
            webView.configuration.userContentController.add(self, name: $0) // 작업 이름을 추가합니다
        }
        
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        self.setupWebViewConstraints()
        
        var reqUrl: URL?

        guard let path = Bundle.main.path(forResource: "demo/index", ofType: "html") else { return }
        reqUrl = URL(fileURLWithPath: path)
        
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        
        webView.load(URLRequest(url: reqUrl!))
    }
    
    private func setupWebViewConstraints() {
        let safeArea = self.view.safeAreaLayoutGuide
        self.webView.do {
            $0.snp.makeConstraints { make in
                make.leading.equalTo(safeArea.snp.leading)
                make.top.equalTo(safeArea.snp.top)
                make.trailing.equalTo(safeArea.snp.trailing)
                make.bottom.equalTo(self.view.snp.bottom)
            }
        }
    }
}

extension ViewController {
    private func onCallback(_ metadata: Metadata, _ methodName: String, _ payload: [String : Any]) -> Void {
        print("callback methodName: ", methodName)
        onComplete(metadata, "window._ios.MessageHandler", methodName, payload)
    }
    
    private func onComplete(_ metadata: Metadata, _ objectName: String, _ methodName: String, _ payload: [String : Any]) -> Void {
        var script = "\(objectName).\(methodName)(\(metadata.sequence));"
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            script = "\(objectName).\(methodName)(\(metadata.sequence), '\(jsonString)');"
        }
        
        print("script: ", script)
        
        webView?.evaluateJavaScript(script) { (_, error) in
            if let error = error {
                print("evaluate error: ", error)
            }
        }
    }
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let name = message.name
        let body = message.body as? [String: Any]
        
        print("name: ", name)
        print("body: ", body)
                
        guard let parameters = message.body as? [String: Any],
              let metaJson = parameters["metadata"] as? [String: Any],
              let sequence = metaJson["sequence"] as? Int else {
            return
        }
                
        let metadata = Metadata(sequence: sequence)
                
        guard let taskHandler = taskHandlers[name] else {
            let payload: [String: Any] = ["success": false]
            onCallback(metadata, "onFailure", payload)

            return
        }

        Task {
            var payload = try await taskHandler(parameters)
            let result = payload["success"] as? Bool ?? false
            if result {
                onCallback(metadata, "onSuccess", payload)
            } else {
                payload = ["success": false]
                onCallback(metadata, "onFailure", payload)
            }
        }
    }
}


extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
    }
}

extension ViewController {
    func urlInvalid(_ url: String) -> Bool {
        if url.hasPrefix("https") || url.hasPrefix("http") || url.hasPrefix("www") {
            return true
        } else {
            return false
        }
    }
}
