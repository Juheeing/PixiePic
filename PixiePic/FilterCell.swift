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
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(filterImageView)
        contentView.addSubview(checkmarkImageView)
        
        filterImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalToSuperview().multipliedBy(0.8)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with imageName: String, isSelected: Bool) {
        filterImageView.image = UIImage(named: imageName)
        checkmarkImageView.isHidden = !isSelected
    }
}
