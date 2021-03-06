//
//  IssueListViewController.swift
//  IssueTracker
//
//  Created by 송민관 on 2020/11/02.
//

import UIKit
import Combine

protocol IssueListDisplayLogic: class {
  func displayFetchedIssues(viewModel: [IssueListViewModel])
}

final class IssueListViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet weak var issueListCollectionView: UICollectionView!
    @IBOutlet weak var issueListToolBar: UIToolbar!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    private var issueListModelController: IssueListModelController!
    private var filterLeftBarButton: UIBarButtonItem!
    private var selectAllLeftBarButton: UIBarButtonItem!
    private var searchText = ""
    private var selectAllFlag = true

    var dataSource: UICollectionViewDiffableDataSource<Section, IssueListViewModel>!
    var displayedIssue = [IssueListViewModel]()
    var interactor: IssueListBusinessLogic!
    
    // MARK: Enums
    
    enum Section: CaseIterable {
        case main
    }

    // MARK: View Cycle
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataSource()
        configureCollectionLayoutList()
        configureNavigationItems()
        issueListModelController = IssueListModelController()
        performApply()
        showSearchBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureToolBar()
        interactor.fetchIssues()
        toggleIndicatorView(state: true)
    }

    // MARK: Setup
    
    private func setup() {
        let interactor = IssueListInteractor()
        let presenter = IssueListPresenter()
        self.interactor = interactor
        interactor.presenter = presenter
        presenter.viewController = self
    }
    
    // MARK: Configure
    
    private func configureNavigationItems() {
        filterLeftBarButton = UIBarButtonItem(title: "Filter",
                                              style: .plain,
                                              target: self,
                                              action: #selector(filterTouched))
        selectAllLeftBarButton = UIBarButtonItem(title: "Select All",
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(selectAllTouched))
        navigationItem.leftBarButtonItem = filterLeftBarButton
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    private func configureToolBar() {
        issueListToolBar.sizeToFit()
        issueListToolBar.isHidden = true
    }
    
    private func showSearchBar() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        navigationItem.hidesSearchBarWhenScrolling = true

        searchController.searchBar.sizeToFit()
        searchController.searchBar.returnKeyType = UIReturnKeyType.search
        searchController.searchBar.placeholder = "Search"
        navigationItem.searchController = searchController
    }
    
    private func toggleIndicatorView(state: Bool) {
        if state {
            indicatorView.isHidden = false
            indicatorView.startAnimating()
        } else {
            indicatorView.stopAnimating()
            indicatorView.isHidden = true
        }
    }
    
    private func configureCollectionLayoutList() {
        if #available(iOS 14.0, *) {
            var layoutConfig = UICollectionLayoutListConfiguration(appearance: .plain)
            layoutConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard let item = self?.dataSource.itemIdentifier(for: indexPath)
                else {
                    return nil
                }
                
                let close = UIContextualAction(style: .destructive,
                                                title: "Close") { [weak self] _, _, completion in
                    guard let id = item.id else { return }
                    self?.toggleIndicatorView(state: true)
                    self?.interactor.closeIssue(id: id, state: 0, handler: {
                        DispatchQueue.main.async { [weak self] in
                            self?.toggleIndicatorView(state: false)
                        }
                    })
                    completion(true)
                }
                close.backgroundColor = .systemRed
                return UISwipeActionsConfiguration(actions: [close])
            }
            let listLayout = UICollectionViewCompositionalLayout.list(using: layoutConfig)
            issueListCollectionView.collectionViewLayout = listLayout
        }
    }
    
    // MARK: Actions
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        tabBarController?.tabBar.isHidden = editing
        issueListToolBar.isHidden = !editing
        issueListToolBar.sizeToFit()
        navigationItem.leftBarButtonItem = editing ? selectAllLeftBarButton : filterLeftBarButton

        if editing {
            navigationItem.rightBarButtonItem?.title = "Cancel"
            navigationItem.rightBarButtonItem?.style = .plain
        }
        
        if #available(iOS 14.0, *) {
            issueListCollectionView.isEditing = editing
            issueListCollectionView.allowsMultipleSelectionDuringEditing = editing
        } else {
            issueListCollectionView.allowsMultipleSelection = editing
        }
    }
    
    @IBAction func closeSelectedIssueTouched(_ sender: UIBarButtonItem) {
        guard let selectedItems = issueListCollectionView
                .indexPathsForSelectedItems?
                .compactMap({ dataSource.itemIdentifier(for: $0) }) else {
            return
        }
        selectedItems.forEach({
            toggleIndicatorView(state: true)
            guard let id = $0.id else { return }
            interactor.closeIssue(id: id, state: 0) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.toggleIndicatorView(state: false)
                }
            }
        })
    }
    
    @objc func filterTouched(_ sender: Any) {
        performSegue(withIdentifier: "IssueListFilterSegue", sender: nil)
    }
    
    @objc func selectAllTouched(_ sender: Any) {
        if selectAllFlag {
            displayedIssue
                .compactMap { dataSource.indexPath(for: $0) }
                .forEach({
                    issueListCollectionView.selectItem(at: $0, animated: true, scrollPosition: .top)
                })
            selectAllFlag.toggle()
        } else {
            displayedIssue
                .compactMap { dataSource.indexPath(for: $0) }
                .forEach({
                    issueListCollectionView.deselectItem(at: $0, animated: true)
                })
            selectAllFlag.toggle()
        }
    }
}

// MARK: IssueListDisplayLogic

extension IssueListViewController: IssueListDisplayLogic {
    func displayFetchedIssues(viewModel: [IssueListViewModel]) {
        displayedIssue = viewModel
        reloadDataSource(items: displayedIssue)
    }
}

// MARK: UISearchBarDelegate

extension IssueListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let filteredData = issueListModelController
            .filteredBasedOnTitle(with: searchText,
                                  model: displayedIssue).sorted { $0.title > $1.title }
        performApply(filtered: filteredData)
        self.searchText = searchText
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        performApply()
        searchBar.resignFirstResponder()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.navigationItem.searchController?.searchBar.text = searchText
    }

    func performApply(filtered: [IssueListViewModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, IssueListViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func performApply() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, IssueListViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(displayedIssue)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.indicatorView.stopAnimating()
            self?.indicatorView.isHidden = true
        }
    }
}

// MARK: UICollectionView DataSource

extension IssueListViewController {
    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, IssueListViewModel>(
            collectionView: issueListCollectionView,
            cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IssueListCell",
                                                                    for: indexPath) as? IssueListCollectionViewCell
                else {
                    return UICollectionViewCell()
                }
                cell.configure(of: item)
                cell.systemLayoutSizeFitting(.init(width: self.view.bounds.width, height: 88))
                return cell
            })
    }

    private func reloadDataSource(items: [IssueListViewModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, IssueListViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false) {
            self.toggleIndicatorView(state: false)
        }
    }
}

// MARK: UICollectionViewDelegate

extension IssueListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard isEditing else {
            let sender = displayedIssue[indexPath.row]
            guard let issueDetailViewController = self.storyboard?.instantiateViewController(
                        identifier: IssueDetailViewController.identifier,
                        creator: { coder -> IssueDetailViewController? in
                            return IssueDetailViewController(coder: coder, id: sender.id, firstComment: sender)
                        }) else { return }

            navigationController?.pushViewController(issueDetailViewController, animated: true)
            return
        }
    }
}
