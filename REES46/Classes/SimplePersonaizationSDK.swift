
//
//  SimplePersonaliztionSDK.swift
//  shopTest
//
//  Created by Арсений Дорогин on 29.07.2020.
//

import Foundation

class SimplePersonaizationSDK: PersonalizationSDK {
    
    var shopId: String
    var userSession: String
    var userSeance: String

    var userId: String?
    var userEmail: String?
    var userPhone: String?
    var userLoyaltyId: String?

    var urlSession: URLSession

    var userInfo: InitResponse = InitResponse()

    private let mySerialQueue = DispatchQueue(label: "myQueue", qos: .background)

    private let semaphore = DispatchSemaphore(value: 0)

    init(shopId: String, userId: String? = nil, userEmail: String? = nil, userPhone: String? = nil, userLoyaltyId: String? = nil) {
        self.shopId = shopId

        self.userId = userId
        self.userEmail = userEmail
        self.userPhone = userPhone
        self.userLoyaltyId = userLoyaltyId

        // Generate seance
        userSeance = UUID().uuidString
        // Trying to fetch user session (permanent user ID)
        userSession = "d701d1af-8cee-48e6-a3ea-e42accd7fc7e"//UserDefaults.standard.string(forKey: "personalization_ssid") ?? ""

        urlSession = URLSession.shared
        mySerialQueue.async {
            self.sendInitRequest { initResult in
                switch initResult {
                case .success:
                    let res = try! initResult.get()
                    self.userInfo = res
                    self.userSeance = res.seance
                    self.userSession = res.ssid
                    self.semaphore.signal()
                case .failure:
                    print("PersonalizationSDK error: SDK INIT FAIL")
                    break
                }
            }
            self.semaphore.wait()
        }
    }

    func getSSID() -> String {
        return userSession
    }

    func getSession() -> String {
        return userSeance
    }

    func setPushTokenNotification(token: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        mySerialQueue.async {
            let path = "mobile_push_tokens"
            let params = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "token": token,
                "platform": "ios",
            ]
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case .success:
                    completion(.success(Void()))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }

    func setProfileData(userEmail: String, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: String?, firstName: String?, secondName: String?, lastName: String?, location: String?, gender: Gender?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        mySerialQueue.async {
            let path = "push_attributes"
            var birthdayString = ""
            if let birthday = birthday {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "YYYY-MM-DD"
                birthdayString = dateFormatter.string(from: birthday)
            }
            let params: [String: String] = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "seance": self.userSeance,
                "attributes[id]": self.userId ?? "",
                "attributes[gender]": gender == .male ? "m" : "f",
                "attributes[birthday]": birthdayString,
                "attributes[age]": age ?? "",
                "attributes[email]": userEmail,
                "attributes[first_name]": firstName ?? "",
                "attributes[middle_name]": secondName ?? "",
                "attributes[last_name]": lastName ?? "",
                "attributes[phone]": userPhone ?? "",
                "attributes[loyality_id]": userLoyaltyId ?? "",
                "attributes[location]": location ?? "",
            ]

            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON["status"] as! String
                    if status == "success" {
                        completion(.success(Void()))
                    } else {
                        completion(.failure(.responseError))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }

    func track(event: Event, completion: @escaping (Result<Void, SDKError>) -> Void) {
        mySerialQueue.async {
            let path = "push"
            var paramEvent = ""
            var params = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "seance": self.userSeance,
            ]
            switch event {
            case let .categoryView(id):
                params["item_id[0]"] = id
                paramEvent = "category"
            case let .productView(id):
                params["item_id[0]"] = id
                paramEvent = "view"
            case let .productAddedToCart(id):
                params["item_id[0]"] = id
                paramEvent = "cart"
            case let .productAddedToFavorities(id):
                params["item_id[0]"] = id
                paramEvent = "wish"
            case let .productRemovedFromCart(id):
                params["item_id[0]"] = id
                paramEvent = "remove_from_cart"
            case let .productRemovedToFavorities(id):
                params["item_id[0]"] = id
                paramEvent = "remove_wish"
            case let .orderCreated(orderId, totalValue, products):
                for (index, item) in products.enumerated() {
                    params["item_id[\(index)]"] = item.id
                    params["amount[\(index)]"] = "\(item.amount)"
                }
                params["order_id"] = orderId
                params["total_value"] = "\(totalValue)"
                paramEvent = "purchase"
            case let .syncronizeCart(ids):
                for (index, item) in ids.enumerated() {
                    params["item_id[\(index)]"] = item
                }
                paramEvent = "cart"
            }
            params["event"] = paramEvent
            self.postRequest(path: path, params: params, completion: { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let status = resJSON["status"] as! String
                    if status == "success" {
                        completion(.success(Void()))
                    } else {
                        completion(.failure(.responseError))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        }
    }

    func recommend(blockId: String, currentProductId: String?, completion: @escaping (Result<RecommenderResponse, SDKError>) -> Void) {
        mySerialQueue.async {
            let path = "recommend"
            let params = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "seance": self.userSeance,
                "recommender_type": "dynamic",
                "recommender_code": blockId,
                "segment": Bool.random() ? "A" : "B",
                "extended": "true",
            ]

            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = RecommenderResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, categories: String?, extended: String?, sortBy: String?, sortDic: String?, locations: String?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: String?, exclude: String?, email: String?, completion: @escaping (Result<SearchResponse, SDKError>) -> Void) {
        mySerialQueue.async {
            let path = "search"
            var params: [String: String] = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "seance": self.userSeance,
                "type": "full_search",
                "search_query": query,
            ]
            if let limit = limit{
                params["limit"] = String(limit)
            }
            if let offset = offset{
                params["offset"] = String(offset)
            }
            if let categoryLimit = categoryLimit{
                params["category_limit"] = String(categoryLimit)
            }
            if let categories = categories{
                params["categories"] = categories
            }
            if let extended = extended{
                params["extended"] = extended
            }
            if let sortBy = sortBy{
                params["sort_by"] = String(sortBy)
            }
            if let limit = limit{
                params["sort_dic"] = String(limit)
            }
            if let locations = locations{
                params["locations"] = locations
            }
            if let brands = brands{
                params["brands"] = brands
            }
            if let filters = filters{
                if let theJSONData = try? JSONSerialization.data(
                    withJSONObject: filters,
                    options: []) {
                    let theJSONText = String(data: theJSONData,
                                             encoding: .utf8)
                    params["filters"] = theJSONText
                }
            }
            if let priceMin = priceMin{
                params["price_min"] = String(priceMin)
            }
            if let priceMax = priceMax{
                params["price_max"] = String(priceMax)
            }
            if let colors = colors{
                params["colors"] = colors
            }
            if let exclude = exclude{
                params["exclude"] = exclude
            }
            if let email = email{
                params["email"] = email
            }
                

            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    
    func suggest(query: String, completion: @escaping (Result<SearchResponse, SDKError>) -> Void) {
        
        mySerialQueue.async {
            let path = "search"
            let params = [
                "shop_id": self.shopId,
                "ssid": self.userSession,
                "seance": self.userSeance,
                "type": "instant_search",
                "search_query": query,
            ]

            self.getRequest(path: path, params: params) { result in
                switch result {
                case let .success(successResult):
                    let resJSON = successResult
                    let resultResponse = SearchResponse(json: resJSON)
                    completion(.success(resultResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    private func sendInitRequest(completion: @escaping (Result<InitResponse, SDKError>) -> Void) {
        let path = "init_script"
        let params = [
            "shop_id": shopId,
        ]

        getRequest(path: path, params: params, true) { result in

            switch result {
            case let .success(successResult):
                let resJSON = successResult
                let resultResponse = InitResponse(json: resJSON)
                UserDefaults.standard.set(resultResponse.ssid, forKey: "personalization_ssid")
                completion(.success(resultResponse))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private let baseURL = "https://api.rees46.com/"

    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-mm-dd"
        jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
        return jsonDecoder
    }()

    private func getRequest(path: String, params: [String: String], _ isInit: Bool = false, completion: @escaping (Result<[String: Any], SDKError>) -> Void) {
        
        let urlString = baseURL + path

        var url = URLComponents(string: urlString)

        var queryItems = [URLQueryItem]()
        for item in params{
            queryItems.append(URLQueryItem(name: item.key, value: item.value))
        }
        url?.queryItems = queryItems
        
        if let endUrl = url?.url {
            urlSession.dataTask(with: endUrl) { result in
                switch result {
                case .success(let (response, data)):
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200 ..< 299 ~= statusCode else {
                        let json = try? JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            let statusMessage = jsonObject["message"] as? String ?? ""
                            print("Status message: ", statusMessage)
                        }
                        completion(.failure(.invalidResponse))
                        return
                    }
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            completion(.success(jsonObject))
                        } else {
                            completion(.failure(.decodeError))
                        }
                    } catch {
                        completion(.failure(.decodeError))
                    }
                case .failure:
                    completion(.failure(.invalidResponse))
                }
            }.resume()
        } else {
            completion(.failure(.invalidResponse))
        }
    }

    private func postRequest(path: String, params: [String: String], completion: @escaping (Result<[String: Any], SDKError>) -> Void) {
        if let url = URL(string: baseURL + path) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let postString = getPostString(params: params)
            request.httpBody = postString.data(using: .utf8)

            urlSession.postTask(with: request) { result in
                switch result {
                case .success(let (response, data)):
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200 ..< 299 ~= statusCode else {
                        completion(.failure(.invalidResponse))
                        return
                    }
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let jsonObject = json as? [String: Any] {
                            completion(.success(jsonObject))
                        } else {
                            completion(.failure(.decodeError))
                        }
                    } catch {
                        completion(.failure(.decodeError))
                    }
                case .failure:
                    completion(.failure(.responseError))
                }
            }.resume()
        } else {
            completion(.failure(.invalidResponse))
        }
    }

    private func getPostString(params: [String: Any]) -> String {
        var data = [String]()
        for (key, value) in params {
            data.append(key + "=\(value)")
        }
        return data.map { String($0) }.joined(separator: "&")
    }
}

extension URLSession {
    func dataTask(with url: URL, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }

    func postTask(with request: URLRequest, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return uploadTask(with: request, from: nil) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            result(.success((response, data)))
        }
    }
}