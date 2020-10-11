//
//  UIView_Extension.swift
//  myblecheck01
//
//  Created by 庄俊亮 on 2018/12/23.
//  Copyright © 2018 庄俊亮. All rights reserved.
//

import UIKit

extension UIView {
	
    /// クラス名と一致していない名前のXibファイルから生成
    /// @param name Xib名前
    /// @param owner オーナー
    /// @return インスタンス
	internal class func loadNib<T: UIView>(name: String, owner: Any?) -> T? {
		
		let bundle: Bundle = Bundle.main
		let response = bundle.loadNibNamed(name, owner: owner, options: nil)?.first
		return response as? T
	}
    
    /// クラス名と一致した名前のXibファイルから生成
    /// @param owner オーナー
    /// @return インスタンス
    internal class func loadNib<T: UIView>(owner: Any?) -> T? {
        // UIViewの型の名前
        let name = String(describing: T.self)
        // UIViewの型の格納したBundle
        let bundle = Bundle(for: T.self)
        // Xibを取得しTとしてインスタンス化
        let response = bundle.loadNibNamed(name, owner: owner, options: nil)?.first
        // インスタンスを返す
        return response as? T
    }
}
