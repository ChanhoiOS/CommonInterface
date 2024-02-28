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
        setWebView()
    }
    
    func setContentController() {
        let contentController = WKUserContentController()
        
        taskHandlers["test"] = { (parameters) in
             Promise<[String: Any]?> { (resolve, _) in
               //... some task
               //if success { // success
                 var result = [String: Any]()
                 result["success"] = true
                 resolve(result)
                 //return
               //}
               //throw TaskError(message: "Illegal State Error!!") // failure
             }
           }

        
        
        webConfiguration.userContentController = contentController
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
    private func onSuccess(_ metadata: Metadata, _ payload: (Promise<[String : Any]?>)) -> Void {
        onComplete(metadata, "window._ios.MessageHandler", "onSuccess", payload)
    }
    
    private func onFailure(_ metadata: Metadata, _ payload: [String : Any]?) -> Void {
        //onComplete(metadata, "window._ios.MessageHandler", "onFailure", payload)
    }
    
    private func onComplete(_ metadata: Metadata, _ objectName: String, _ methodName: String, _ payload: (Promise<[String : Any]?>)) -> Void {
        var script = "\(objectName).\(methodName)(\(metadata.sequence));"
        
//        if let payload = payload, let json = JSON.stringify(payload) {
//            script = "\(objectName).\(methodName)(\(metadata.sequence), '\(json)');"
//        }
        script = "\(objectName).\(methodName)(\(metadata.sequence), {success: true});"
        
        print("script: ", script)
        webView?.evaluateJavaScript(script) { (_, error) in
            //Logger.debug(script)
            if let error = error {
              //  Logger.error(error.localizedDescription)
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
            let payload: [String: Any] = ["message": "handler with name '\(name)' not exists"]
            onFailure(metadata, payload)

            return
        }

        Task {
            do {
                let payload = try await(taskHandler(parameters))
                print("payload: ", payload)
                onSuccess(metadata, payload)
            } catch let error {
                var message = "Unknown Error"
                if let error = error as? TaskError {
                    message = error.message
                } else {
                    message = error.localizedDescription
                }
                let payload: [String: Any] = ["message": message]
                onFailure(metadata, payload)
            }
        }
    }
}


extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
    }
}

