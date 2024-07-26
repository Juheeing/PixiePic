//
//  FilterCell.swift
//  PixiePic
//
//  Created by 김주희 on 2024/07/26.
//

import UIKit
import SnapKit

class FilterCell: UICollectionViewCell {
    static let identifier = "FilterCell"

    private let filterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(filterImageView)
        filterImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with imageName: String) {
        filterImageView.image = UIImage(named: imageName)
    }
}

