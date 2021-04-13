//
//  ImageSlideViewController.swift
//
//  Created by Dimitri Giani on 02/11/15.
//  Copyright © 2015 Dimitri Giani. All rights reserved.
//

import UIKit

class ImageSlideViewController: UIViewController, UIScrollViewDelegate
{
	@IBOutlet weak var scrollView:UIScrollView?
	@IBOutlet weak var imageView:UIImageView?
	@IBOutlet weak var loadingIndicatorView:UIActivityIndicatorView?
	
	var slide:ImageSlideShowProtocol?
	var enableZoom = false
    var doubleTabZoomScale: CGFloat = 2.0

	var willBeginZoom:() -> Void = {}
	
    var customActivityIndicatorView: UIView?
    var startAnimationActivityIndicator: ((_ spinner: UIView?) -> Void)? = { _ in }
    var stopAnimationActivityIndicator: ((_ spinner: UIView?) -> Void)? = { _ in }

    var onImageError: ((_ viewController: UIViewController,_ containerView: UIView?, _ error: Error?) -> Void)? = nil
    
    private var cachedImage: UIImage? = nil

	
	override func viewDidLoad()
	{
		
        if #available(iOS 11.0, *) {
            self.scrollView?.contentInsetAdjustmentBehavior = .never
        }
		
		super.viewDidLoad()
		
		if enableZoom
		{
			scrollView?.maximumZoomScale = 16.0
			scrollView?.minimumZoomScale = 1.0
			scrollView?.zoomScale = 1.0
		}
		
		scrollView?.isHidden = true
        
        
        if let _customActivityIndicatorView = self.customActivityIndicatorView {
            self.loadingIndicatorView?.removeFromSuperview()
            self.loadingIndicatorView = nil

            self.view.addSubview(_customActivityIndicatorView)
            _customActivityIndicatorView.widthAnchor.constraint(equalToConstant: _customActivityIndicatorView.frame.width).isActive = true
            _customActivityIndicatorView.heightAnchor.constraint(equalToConstant: _customActivityIndicatorView.frame.height).isActive = true
            _customActivityIndicatorView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            _customActivityIndicatorView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
            _customActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
	        self.startAnimationActivityIndicator?(self.customActivityIndicatorView)			
        } else {
	        self.loadingIndicatorView?.startAnimating()
        }

        self.loadImage()
    }
	
	override func viewDidDisappear(_ animated: Bool)
	{
		super.viewDidDisappear(animated)
		
		if enableZoom
		{
			//	Reset zoom scale when the controller is hidden
		
			scrollView?.zoomScale = 1.0
		}
	}
	
	//	MARK: UIScrollViewDelegate
	
	func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?)
	{
		willBeginZoom()
	}
	
	func viewForZooming(in scrollView: UIScrollView) -> UIView?
	{
		if enableZoom
		{
			return imageView
		}
		
		return nil
	}
    
    // MARK :
    public func loadImage() {
        
        let onCompleted: (() -> Void) = {
            self.loadingIndicatorView?.stopAnimating()
            self.stopAnimationActivityIndicator?(self.customActivityIndicatorView)
            self.scrollView?.isHidden = false
        }

        
        if let _cachedImage: UIImage = self.cachedImage {
            self.imageView?.image = _cachedImage
            onCompleted()
        } else {
            self.slide?.image(completion: { (image, error) -> Void in
                
                guard (error == nil) else {
                    self.onImageError?(self, self.imageView, error)
                    self.cachedImage = nil
                    onCompleted()
                    return
                }
                
                DispatchQueue.main.async {
                    if let _imageView: UIImageView = self.imageView {
                        _imageView.image = image
                    } else {
                        self.cachedImage = image
                    }
                    
                    onCompleted()
                }
            })
        }
    }
}
