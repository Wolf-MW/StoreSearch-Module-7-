//
//  Search.swift
//  StoreSearch
//
//  Created by Matthew Wolf on 2/23/21.
//  Copyright © 2021 Matthew Wolf. All rights reserved.
//

import Foundation

typealias SearchComplete = (Bool) -> Void
class Search {
  enum Category: Int {
    case all = 0
    case music = 1
    case software = 2
    case ebooks = 3
    
    var type: String {
        switch self {
        case .all: return ""
        case .music: return "musicTrack"
        case .software: return "software"
        case .ebooks: return "ebook"
        }
    }
  }
    enum State {
      case notSearchedYet
      case loading
      case noResults
      case results([SearchResult])
    }
    private(set) var state: State = .notSearchedYet
    private var dataTask: URLSessionDataTask? = nil
    
    func performSearch(for text: String, category: Category, completion: @escaping SearchComplete) {
    if !text.isEmpty {
        dataTask?.cancel()
        state = .loading
        let url = iTunesURL(searchText: text, category: category)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: {
          data, response, error in
          var newState = State.notSearchedYet
          var success = false
          if let error = error as NSError?, error.code == -999 {
            return
          }
          if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
            var searchResults = self.parse(data: data)
            if searchResults.isEmpty {
                newState = .noResults
            } else {
                searchResults.sort(by: <)
                newState = .results(searchResults)
            }
            success = true
          }
        
            DispatchQueue.main.async {
                self.state = newState
                completion(success)
            }
        })
        dataTask?.resume()
    }
  }
    
    private func iTunesURL(searchText: String, category: Category) -> URL {
          let locale = Locale.autoupdatingCurrent
          let language = locale.identifier
          let countryCode = locale.regionCode ?? "US"
          let kind = category.type
          let encodedText = searchText.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
          let urlString = "https://itunes.apple.com/search?" +
            "term=\(encodedText)&limit=200&entity=\(kind)" +
            "&lang=\(language)&country=\(countryCode)"
          let url = URL(string: urlString)
          print("URL: \(url!)")
        return url!
    }
    
    func parse(data: Data) -> [SearchResult] {
      do {
        let decoder = JSONDecoder()
        let result = try decoder.decode(ResultArray.self, from:data)
        return result.results
      } catch {
        print("JSON Error: \(error)")
        return []
        }
    }
    
}
