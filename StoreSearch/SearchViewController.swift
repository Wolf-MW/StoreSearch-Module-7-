//
//  ViewController.swift
//  StoreSearch
//
//  Created by Matthew Wolf on 2/16/21.
//  Copyright © 2021 Matthew Wolf. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController {
  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  var searchResults = [SearchResult]()
  var hasSearched = false
  var isLoading = false
  var dataTask: URLSessionDataTask?
    
    struct TableView {
      struct CellIdentifiers {
        static let searchResultCell = "SearchResultCell"
        static let nothingFoundCell = "NothingFoundCell"
        static let loadingCell = "LoadingCell"
        
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.contentInset = UIEdgeInsets(top: 108, left: 0, bottom: 0, right: 0)
        var cellNib = UINib(nibName: TableView.CellIdentifiers.searchResultCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.searchResultCell)
        
        cellNib = UINib(nibName: TableView.CellIdentifiers.nothingFoundCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier:
          TableView.CellIdentifiers.nothingFoundCell)
        searchBar.becomeFirstResponder()
        cellNib = UINib(nibName: TableView.CellIdentifiers.loadingCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.loadingCell)
        
        let segmentColor = UIColor(red: 10/255, green: 80/255, blue: 80/255, alpha: 1)
        let selectedTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        let normalTextAttributes = [NSAttributedString.Key.foregroundColor: segmentColor]
        segmentedControl.selectedSegmentTintColor = segmentColor
        segmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .highlighted)
    }
    
    func iTunesURL(searchText: String, category: Int) -> URL {
        let kind: String
          switch category {
            case 1: kind = "musicTrack"
            case 2: kind = "software"
            case 3: kind = "ebook"
            default: kind = ""
          }
          let encodedText = searchText.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
          let urlString = "https://itunes.apple.com/search?" + "term=\(encodedText)&limit=200&entity=\(kind)"
          let url = URL(string: urlString)
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
    
    func showNetworkError() {
      let alert = UIAlertController(title: "Whoops...",
        message: "There was an error accessing the iTunes Store." +
        " Please try again.", preferredStyle: .alert)
      let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        present(alert, animated: true, completion: nil)
        alert.addAction(action)
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        performSearch()
    }
    
}

extension SearchViewController: UISearchBarDelegate {
  func position(for bar: UIBarPositioning) -> UIBarPosition {
    return .topAttached
  }
    
     func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
      performSearch()
    }
    func performSearch() {
        if !searchBar.text!.isEmpty {
            searchBar.resignFirstResponder()
            
            dataTask?.cancel()
            isLoading = true
            tableView.reloadData()
            
            hasSearched = true
            searchResults = []
    
             let url = iTunesURL(searchText: searchBar.text!, category: segmentedControl.selectedSegmentIndex)
            let session = URLSession.shared
            dataTask = session.dataTask(with: url, completionHandler: { data, response, error in
                   if let error = error as NSError?, error.code == -999 {
                        return
                  } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let data = data {
                        self.searchResults = self.parse(data: data)
                        self.searchResults.sort(by: <)
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.tableView.reloadData()
                        }
                        return
                    }
                  } else {
                    print("Failure! \(response!)")
                  }
                DispatchQueue.main.async {
                  self.hasSearched = false
                  self.isLoading = false
                  self.tableView.reloadData()
                  self.showNetworkError()
                }
                
            })
            dataTask?.resume()
        }
    }
}

extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isLoading {
    return 1
    } else if !hasSearched {
      return 0
    } else if searchResults.count == 0 {
      return 1
    } else {
      return searchResults.count
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if isLoading {
      let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.loadingCell, for: indexPath)
      let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView
      spinner.startAnimating()
      return cell
    } else
    if searchResults.count == 0 {
      return tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.nothingFoundCell, for: indexPath)
    } else {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.searchResultCell, for: indexPath) as! SearchResultCell
        let searchResult = searchResults[indexPath.row]
        cell.nameLabel.text = searchResult.name
        if searchResult.artist.isEmpty {
            cell.artistNameLabel.text = "Unknown"
        } else {
            cell.artistNameLabel.text = String(format: "%@ (%@)", searchResult.artist, searchResult.type)
        }
        return cell
        
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    if searchResults.count == 0 || isLoading {
      return nil
    } else {
      return indexPath
    }
  }
    
}

func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
  return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
}
