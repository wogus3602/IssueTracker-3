//
//  IssueListCollectionViewCell.swift
//  IssueTracker
//
//  Created by ParkJaeHyun on 2020/11/03.
//

import UIKit

final class IssueListCollectionViewCell: UICollectionViewListCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var mileStone: UIButton!
    @IBOutlet private weak var firstLabel: UIButton!
    @IBOutlet private weak var secondLabel: UIButton!
    
    var isInEditingMode: Bool = false {
        didSet {
            toggleEditingMode()
        }
    }

    override var isSelected: Bool {
        didSet {
            if isInEditingMode {
                backgroundColor = .systemGray4
            }
        }
    }
    
    func configureIssueListCell(of item: IssueListViewModel) {
        titleLabel.text = item.title
        descriptionLabel.text = item.description
        firstLabel.titleLabel?.text = item.labels.first
        secondLabel.titleLabel?.text = item.labels.last
        mileStone.titleLabel?.text = item.milestone
    }
    
    // TODO: Moving Animation
    private func toggleEditingMode() {
        if isInEditingMode {
            contentView.layer.bounds.origin.x -= 40
        } else {
            contentView.layer.bounds.origin.x += 40
        }
    }
}