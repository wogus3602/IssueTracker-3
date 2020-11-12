//
//  IssueListViewController.swift
//  IssueTracker
//
//  Created by 송민관 on 2020/11/02.
//

import UIKit
import Combine

// FIXME: ToolBar Editing Mode에서 저~~~~ 밑으로 내려가는 문제 해결
// FIXME: SelectAll 문제 - 전체 다 안됨 (겉으로 보기에만 됨 / 여러번 하면 오류 + cell 위치 틀리는 문제 / Model data를 변경해야함)

protocol IssueListDisplayLogic: class {
  func displayFetchedIssues(viewModel: [IssueListViewModel])
}

final class IssueListViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet private weak var issueListCollectionView: UICollectionView!
    @IBOutlet private weak var issueListToolBar: UIToolbar!
    @IBOutlet private weak var indicatorView: UIActivityIndicatorView!
    
    private var interactor: IssueListBusinessLogic!
    private var dataSource: UICollectionViewDiffableDataSource<Section, IssueListViewModel>!
    private var issueListModelController: IssueListModelController!
    private var filterLeftBarButton: UIBarButtonItem!
    private var selectAllLeftBarButton: UIBarButtonItem!
    private var searchText = ""
    private var selectAllFlag = true

    // MARK: Enums
    
    enum Section: CaseIterable {
        case main
    }
    
    enum UpdateDataSourceType {
        case append, delete
    }
    
    // MARK: View Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        configureDataSource()
        configureCollectionLayoutList()
        configureNavigationItems()
        issueListModelController = IssueListModelController()
        performSearchQuery(with: nil)
        showSearchBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        issueListToolBar.isHidden = true
        interactor.fetchIssues()
        indicatorView.startAnimating()
    }

    private var displayedIssue = [IssueListViewModel]()

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
    
    func showSearchBar() {
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
    
    private func configureCollectionLayoutList() {
        if #available(iOS 14.0, *) {
            var layoutConfig = UICollectionLayoutListConfiguration(appearance: .plain)
            layoutConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard let item = self?.dataSource.itemIdentifier(for: indexPath) else {
                    return nil
                }
                
                let close = UIContextualAction(style: .destructive,
                                                title: "Close") { [weak self] _, _, completion in
                    // TODO: Model -> 해당 indexPath delete
                    self?.updateDataSource(items: [item], type: .delete)
                    // TODO: 선택 이슈 삭제 -> 삭제 이슈 Model Update & Server Post
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
        updateDataSource(items: selectedItems, type: .delete)
        // TODO: 선택 이슈 닫기 -> 닫은 이슈 Model Update & Server Post
    }
    
    @objc private func filterTouched(_ sender: Any) {
        performSegue(withIdentifier: "IssueListFilterSegue", sender: nil)
    }
    
    @objc private func selectAllTouched(_ sender: Any) {
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
        indicatorView.stopAnimating()
        indicatorView.isHidden = true
    }    
}

// MARK: UISearchBarDelegate

extension IssueListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearchQuery(with: searchText)
        self.searchText = searchText
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        performSearchQuery(with: "")
        searchBar.resignFirstResponder()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.navigationItem.searchController?.searchBar.text = searchText
    }
    
    func performSearchQuery(with filter: String?) {
        let issueListItems = issueListModelController
            .filteredBasedOnTitle(with: filter ?? "",
                                  model: displayedIssue).sorted { $0.title > $1.title }
        var snapshot = NSDiffableDataSourceSnapshot<Section, IssueListViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(issueListItems)
        dataSource.apply(snapshot, animatingDifferences: false)
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
        dataSource.apply(snapshot, animatingDifferences: false)
    }
  
    private func updateDataSource(items: [IssueListViewModel], type: UpdateDataSourceType) {
        var snapshot = dataSource.snapshot()
        switch type {
        case .append:
            snapshot.appendItems(items, toSection: .main)
        case .delete:
            snapshot.deleteItems(items)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
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
