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
	
	var willBeginZoom:() -> Void = {}
	
    private var cachedImage: UIImage? = nil
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		if enableZoom
		{
			scrollView?.maximumZoomScale = 2.0
			scrollView?.minimumZoomScale = 1.0
			scrollView?.zoomScale = 1.0
		}
		
		scrollView?.isHidden = true
		loadingIndicatorView?.startAnimating()
		
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
	
    // MARK : load image or preload
	
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
