import UIKit

class MainViewController: UITableViewController, UISearchBarDelegate {
    var images: [ImageItem] = []
    var totalPages: Int = 0
    var currentPage: Int = 1
    var allImagesDownloaded: Bool = false
    var searchTerm: String = ""
    var numberOfImagesToSave: Int = 0
    var numberOfImagesSaved: Int = 0
    let searchBar = UISearchBar()
    let activityIndicator = UIActivityIndicatorView()
    var alertPleaseWait = UIAlertController()
    
    @IBOutlet weak var toolbarSave: UIBarButtonItem!
    @IBOutlet weak var toolbarSelect: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createSearchBar()
        createActivityIndicator()
    }
    
    func requestImages(searchTerm: String, page: Int) {
        if let url = createUrl(searchTerm: searchTerm, page: page) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                self.stopActivityIndicator()

                if error != nil {
                    self.showRequestError(error: error!.localizedDescription)
                    return
                }
                
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        // save the number of pages
                        if let total = json?["total_pages"] as? Int {
                            self.totalPages = total
                            self.currentPage += 1
                            
                            self.updateToolbar()
                        }
                        
                        // create a new image object for each result
                        if let resultsJson = json?["results"] as? [[String : AnyObject]] {
                            // check if there are no results
                            if resultsJson.count == 0 {
                                self.showNoResultsMessage()
                                return
                            }
                            
                            for result in resultsJson {
                                self.createImageItem(dictionary: result)
                            }
                            
                            if self.currentPage == self.totalPages {
                                self.allImagesDownloaded = true
                            }
                        }
                    } catch {
                        print("There was a problem parsing JSON")
                    }
                }
            }.resume()
        }
        else {
            print("There was a problem with the request")
            self.stopActivityIndicator()
        }
    }
    
    func createImageItem(dictionary: [String : AnyObject]) {
        let image = ImageItem()
        
        if let description = dictionary["description"] as? String {
            image.description = description
        }
        if let user = dictionary["user"] as? [String : AnyObject] {
            image.author = user["name"] as? String
        }
        if let user = dictionary["urls"] as? [String : AnyObject] {
            if let urlBigImage = user["regular"] as? String {
                image.fullsizeUrl = urlBigImage
            }
            
            if let urlString = user["thumb"] as? String {
                if let url = URL(string: urlString) {
                    URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                        if error != nil {
                            print(error ?? "unknown error")
                            return
                        }
                        
                        if let downloadedImage = UIImage(data: data!) {
                            image.image = downloadedImage
                            // update the table view
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                                // if there were previously selected rows, select in table view again after reload
                                self.selectRows()
                            }
                        }
                    }).resume()
                }
            }
        }

        self.images.append(image)
    }
    
    // MARK: - Helper functions
    func createSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search images here"
        self.navigationItem.titleView = searchBar
        
        // create a gesture recognizer to dismiss search bar keyboard when tapped outside
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTapOutside))
        gesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(gesture)
    }
    
    @objc func handleTapOutside() {
        searchBar.resignFirstResponder()
    }
    
    func createActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = self.tableView.center
        activityIndicator.color = .gray
        self.view.addSubview(activityIndicator)
        
        alertPleaseWait = UIAlertController(title: "Downloading images, please wait...", message: "", preferredStyle: .alert)
    }
    
    func showPleaseWaitAlert() {
        present(alertPleaseWait, animated: true)
    }
    
    func hidePleaseWaitAlert() {
        dismiss(animated: true, completion: nil)
    }
    
    func resetAllData() {
        totalPages = 0
        currentPage = 1
        allImagesDownloaded = false
        images.removeAll()
        tableView.reloadData()
        toolbarSave.isEnabled = false
        toolbarSelect.isEnabled = false
        numberOfImagesToSave = 0
        numberOfImagesSaved = 0
    }
    
    func finishImageSaving() {
        numberOfImagesToSave = 0
        numberOfImagesSaved = 0
        tableView.setEditing(false, animated: true)
        toolbarSelect.title = "Select"
        toolbarSelect.tag = 0
        toolbarSave.isEnabled = false
    }
    
    func updateToolbar() {
        DispatchQueue.main.async {
            if self.totalPages > 0 {
                self.toolbarSelect.isEnabled = true
            }
        }
    }
    
    func stopActivityIndicator() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
        }
    }
    
    func showRequestError(error: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    func showNoResultsMessage() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Sorry", message: "No images found, please try again", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    func selectRows() {
        for i in 0...images.count-1 {
            if images[i].selected {
                let indexPath = IndexPath(item: i, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
            }
        }
    }
    
    func createUrl(searchTerm: String, page: Int) -> URL? {
        let urlBase = "https://api.unsplash.com/search/photos/"
        let clientId = URLQueryItem(name: "client_id", value: "6cc6faae31db70f306715da5c0b5eaee9bbd48ad1138ba0499971eabaa66136a")
        let itemsPerPage = URLQueryItem(name: "per_page", value: "20")
        let page = URLQueryItem(name: "page", value: String(page))
        let query = URLQueryItem(name: "query", value: searchTerm)
        
        var components = URLComponents()
        components.queryItems = [clientId, itemsPerPage, page, query]
        
        if let urlString = components.url {
            let finalUrl = urlBase+urlString.absoluteString
            return URL(string: finalUrl)
        }
        
        return nil
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageCell
        
        let imageItem: ImageItem = images[indexPath.row]
        cell.previewImage?.image = imageItem.image
        cell.authorLabel?.text = imageItem.author
        cell.descriptionLabel?.text = imageItem.description
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // if we're on the last element load more images
        if !allImagesDownloaded && indexPath.row == images.count - 1 {
            requestImages(searchTerm: searchTerm, page: currentPage)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        toolbarSave.isEnabled = true
        images[indexPath.row].selected = true
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        // disable save button if no images are selected
        if tableView.indexPathsForSelectedRows == nil {
            toolbarSave.isEnabled = false
        }
        
        images[indexPath.row].selected = false
    }
    
    // MARK: - Search Bar delegates
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        resetAllData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        resetAllData()
        activityIndicator.startAnimating()
        
        if let searchText = searchBar.text {
            searchTerm = searchText
            requestImages(searchTerm: searchTerm, page: currentPage)
        }
    }
    
    // MARK: - Button callbacks
    @IBAction func handleSelectCancel(_ sender: UIBarButtonItem) {
        // handle select
        if sender.tag == 0 {
            tableView.setEditing(true, animated: true)
            sender.title = "Cancel"
            sender.tag = 1
        }
        // handle cancel
        else {
            tableView.setEditing(false, animated: true)
            sender.title = "Select"
            sender.tag = 0
            toolbarSave.isEnabled = false
        }
    }
    
    @IBAction func handleSave(_ sender: UIBarButtonItem) {
        if let selectedRows = tableView.indexPathsForSelectedRows {
            numberOfImagesToSave = selectedRows.count
            showPleaseWaitAlert()
            
            // start a download for every selected image
            for indexPath in selectedRows {
                if let imageUrl = images[indexPath.row].fullsizeUrl {
                    if let url = URL(string: imageUrl) {
                        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                            if error != nil {
                                print(error ?? "unknown error")
                                return
                            }
                            
                            // on successfull download save the image to camera roll
                            if let downloadedImage = UIImage(data: data!) {
                                UIImageWriteToSavedPhotosAlbum(downloadedImage, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                            }
                        }).resume()
                        
                    }
                }
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        // if there was a problem show an error message
        if let error = error {
            hidePleaseWaitAlert()
            let alert = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        else {
            // when all images are saved show a confirmation
            numberOfImagesSaved += 1
            if numberOfImagesToSave == numberOfImagesSaved {
                finishImageSaving()
                hidePleaseWaitAlert()
                let alert = UIAlertController(title: "Saved", message: "The images were saved to your photos", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}
