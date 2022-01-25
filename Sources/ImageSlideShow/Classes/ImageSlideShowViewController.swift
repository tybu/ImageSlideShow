//
//  ImageSlideShowViewController.swift
//
//  Created by Dimitri Giani on 02/11/15.
//  Copyright © 2015 Dimitri Giani. All rights reserved.
//

import UIKit

public protocol ImageSlideShowProtocol
{
	var title: String? { get }
	
	func slideIdentifier() -> String
	func image(completion: @escaping (_ image:UIImage?, _ error:Error?) -> Void)
}

class ImageSlideShowCache: NSCache<AnyObject, AnyObject>
{
	override init()
	{
		super.init()
		
		NotificationCenter.default.addObserver(self, selector:#selector(NSMutableArray.removeAllObjects), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
	}
	
	deinit
	{
		NotificationCenter.default.removeObserver(self);
	}
}

open class ImageSlideShowViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate
{
	static var imageSlideShowStoryboard:UIStoryboard = UIStoryboard(name: "ImageSlideShow", bundle: Bundle(for: ImageSlideShowViewController.self))
	
	open var slides: [ImageSlideShowProtocol]?
	open var initialIndex: Int = 0
	open var pageSpacing: CGFloat = 10.0
	open var panDismissTolerance: CGFloat = 30.0
	open var dismissOnPanGesture: Bool = false
    open var enableZoomOnDoubleTapGesture: Bool = false
	open var enableZoom: Bool = false
	open var statusBarStyle: UIStatusBarStyle = .lightContent
	open var navigationBarTintColor: UIColor = .white
	open var hideNavigationBarOnAction: Bool = true
    open var hideNavigationBarOnPageTransition: Bool = true
	
	//	Current index and slide
	public var currentIndex: Int {
		return _currentIndex
	}
	public var currentSlide: ImageSlideShowProtocol? {
		return slides?[currentIndex]
	}
	
	public var slideShowViewDidLoad: (()->())?
	public var slideShowViewWillAppear: ((_ animated: Bool)-> ())?
	public var slideShowViewDidAppear: ((_ animated: Bool)-> ())?
    public var showAction: (() -> Void) = {}
	
    open var controllerWillDismiss:() -> Void = {}
    open var controllerDidDismiss:() -> Void = {}
	open var stepAnimate:((_ offset:CGFloat, _ viewController:UIViewController) -> Void) = { _,_ in }
	open var restoreAnimation:((_ viewController:UIViewController) -> Void) = { _ in }
	open var dismissAnimation:((_ viewController:UIViewController, _ panDirection:CGPoint, _ completion: @escaping ()->()) -> Void) = { _,_,_ in }
    open var willBeginZoom: (() -> Void)? = nil
    
    open var getCustomActivityIndicatorView: (() -> UIView?)?
    open var startAnimationActivityIndicator: ((_ spinner: UIView?) -> Void)? = { _ in }
    open var stopAnimationActivityIndicator: ((_ spinner: UIView?) -> Void)? = { _ in }
    
    open var onImageError: ((_ viewController: UIViewController,_ containerView: UIView?, _ error: Error?) -> Void)? = nil
	
    
    open var navigationRightBarButtonItems: [UIBarButtonItem]?
    open var navigationLeftBarButtonItems: [UIBarButtonItem]?
    
    open var navigationBarBackgroundColor: UIColor = .black
	
	fileprivate var originPanViewCenter:CGPoint = .zero
	fileprivate var panViewCenter:CGPoint = .zero
	fileprivate var navigationBarHidden = false
	fileprivate var toggleBarButtonItem:UIBarButtonItem?
	fileprivate var _currentIndex: Int = 0
	fileprivate let slidesViewControllerCache = ImageSlideShowCache()
    
    fileprivate var _statusBarView: UIView?
    private var statusBarView: UIView? {
        if self._statusBarView == nil,
           let navigationBar = self.navigationController?.navigationBar {
            
            let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height

            let statusBarView: UIView = UIView()
            navigationBar.addSubview(statusBarView)

            statusBarView.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor).isActive = true
            statusBarView.bottomAnchor.constraint(equalTo: navigationBar.topAnchor ).isActive = true
            statusBarView.widthAnchor.constraint(equalTo: navigationBar.widthAnchor, multiplier: 1.0).isActive = true
            statusBarView.heightAnchor.constraint(equalToConstant: statusBarHeight).isActive = true
            statusBarView.translatesAutoresizingMaskIntoConstraints = false
            
            self._statusBarView = statusBarView
        }
        
        return self._statusBarView
    }

	
	override open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return .fade
	}
	
	override open var preferredStatusBarStyle: UIStatusBarStyle
	{
		return statusBarStyle
	}
	
	override open var prefersStatusBarHidden: Bool
	{
		return navigationBarHidden
	}
	
	override open var shouldAutorotate: Bool
	{
		return true
	}
	
	override open var supportedInterfaceOrientations: UIInterfaceOrientationMask
	{
		return .all
	}
	
	//	MARK: - Class methods
	
    class func imageSlideShowNavigationController(modalTransitionStyle: UIModalTransitionStyle = .coverVertical) -> ImageSlideShowNavigationController
	{
		let controller = ImageSlideShowViewController.imageSlideShowStoryboard.instantiateViewController(withIdentifier: "ImageSlideShowNavigationController") as! ImageSlideShowNavigationController
		controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = modalTransitionStyle
		controller.modalPresentationCapturesStatusBarAppearance = true
		
		return controller
	}
	
	class func imageSlideShowViewController() -> ImageSlideShowViewController
	{
		let controller = ImageSlideShowViewController.imageSlideShowStoryboard.instantiateViewController(withIdentifier: "ImageSlideShowViewController") as! ImageSlideShowViewController
		controller.modalPresentationStyle = .overCurrentContext
		controller.modalPresentationCapturesStatusBarAppearance = true
		
		return controller
	}
	
    class open func presentFrom(_ viewController:UIViewController, modalTransition: UIModalTransitionStyle = .coverVertical, configure:((_ controller: ImageSlideShowViewController) -> ())?)
	{
		let navController = self.imageSlideShowNavigationController(modalTransitionStyle: modalTransition)
		if let issViewController = navController.visibleViewController as? ImageSlideShowViewController
		{
			configure?(issViewController)
			
			viewController.present(navController, animated: true, completion: nil)
		}
	}
	
	required public init?(coder: NSCoder)
	{
		super.init(coder: coder)
		
		prepareAnimations()
	}
	
	//	MARK: - Instance methods
	
	override open func viewDidLoad()
	{
		super.viewDidLoad()
		
		delegate = self
		dataSource = self
		
		hidesBottomBarWhenPushed = true
		
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
		navigationController?.navigationBar.shadowImage = UIImage()		
        navigationController?.navigationBar.backgroundColor = self.navigationBarBackgroundColor
		navigationController?.navigationBar.tintColor = navigationBarTintColor
		navigationController?.view.backgroundColor = .black
        navigationItem.rightBarButtonItems = self.navigationRightBarButtonItems ?? [UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss(sender:)))]
        navigationItem.leftBarButtonItems = self.navigationLeftBarButtonItems

        self.statusBarView?.backgroundColor = self.navigationBarBackgroundColor
		
		//	Manage Gestures
		
		var gestures = gestureRecognizers
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGesture(gesture:)))
        tapGesture.numberOfTapsRequired = 1
		gestures.append(tapGesture)
		
		if (dismissOnPanGesture)
		{
			let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(gesture:)))
			gestures.append(panGesture)
			
			//	If dismiss on pan lock horizontal direction and disable vertical pan to avoid strange behaviours
			
			scrollView()?.isDirectionalLockEnabled = true
			scrollView()?.alwaysBounceVertical = false
		}
        
        if (self.enableZoomOnDoubleTapGesture) {
            let doubleTabGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(gesture:)))
            doubleTabGesture.numberOfTapsRequired = 2
            gestures.append(doubleTabGesture)
            
            tapGesture.require(toFail: doubleTabGesture)
        }
		
		view.gestureRecognizers = gestures
		
		slideShowViewDidLoad?()
	}
	
	override open func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		
		setPage(withIndex: initialIndex)
		
		slideShowViewWillAppear?(animated)
	}
	
	override open func viewDidAppear(_ animated: Bool)
	{
		super.viewDidAppear(animated)
		
		slideShowViewDidAppear?(animated)
	}
	
	//	MARK: Actions
    @objc open func callShowAction() {
        showAction()
    }
    
    @objc open func dismiss(sender:AnyObject?) {
        self.dismiss(sender: sender, animated: true)
    }
	
    @objc open func dismiss(sender:AnyObject?, animated: Bool = true)
	{
        self.controllerWillDismiss()
        dismiss(animated: animated, completion: {
            self.controllerDidDismiss()
        })
	}
	
	open func goToPage(withIndex index:Int)
	{
		if index != _currentIndex
		{
			setPage(withIndex: index)
		}
	}
	
	open func goToNextPage()
	{
		let index = _currentIndex + 1
		if index < (slides?.count)!
		{
			setPage(withIndex: index)
		}
	}
	
	open func goToPreviousPage()
	{
		let index = _currentIndex - 1
		if index >= 0
		{
			setPage(withIndex: index)
		}
	}
	
	func setPage(withIndex index:Int)
	{
		if	let viewController = slideViewController(forPageIndex: index)
		{
			setViewControllers([viewController], direction: (index > _currentIndex ? .forward : .reverse), animated: true, completion: nil)
			
			_currentIndex = index
			
			updateSlideBasedUI()
		}
        
        //preload prev / next
        if index > 0 {
            self.preloadPage(index: index - 1)
        }
        if let _slidesCount: Int = self.slides?.count,
           index < _slidesCount - 1 {
            self.preloadPage(index: index + 1)
        }
	}
	
	func setNavigationBar(visible:Bool)
	{
		guard hideNavigationBarOnAction else { return }
		
		navigationBarHidden = !visible

		navigationController?.setNavigationBarHidden(!visible, animated: true)
		
        UIView.animate(withDuration: 0.23) { self.setNeedsStatusBarAppearanceUpdate() }

	}
	
	// MARK: UIPageViewControllerDataSource
	
	public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController])
	{
        guard self.hideNavigationBarOnPageTransition else { return }
		self.setNavigationBar(visible: false)
	}
	
	public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
	{
		if completed
		{
			_currentIndex = indexOfSlideForViewController(viewController: (pageViewController.viewControllers?.last)!)
			
			updateSlideBasedUI()
		}
	}
	
	public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
	{
		let index = indexOfSlideForViewController(viewController: viewController)
		
		if index > 0
		{
			return slideViewController(forPageIndex: index - 1)
		}
		else
		{
			return nil
		}
	}
	
	public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
	{
		let index = indexOfSlideForViewController(viewController: viewController)
		
		if let slides = slides, index < slides.count - 1
		{
			return slideViewController(forPageIndex: index + 1)
		}
		else
		{
			return nil
		}
	}
    
    private func preloadPage(index: Int) {
        let vc: ImageSlideViewController? = self.slideViewController(forPageIndex: index)
        vc?.loadImage()
    }
	
	// MARK: Accessories
	
	private func indexOfProtocolObject(inSlideViewController controller: ImageSlideViewController) -> Int?
	{
		var index = 0
		
		if	let object = controller.slide,
			let slides = slides
		{
			for slide in slides
			{
				if slide.slideIdentifier() == object.slideIdentifier()
				{
					return index
				}
				
				index += 1
			}
		}
		
		return nil
	}
	
	private func indexOfSlideForViewController(viewController: UIViewController) -> Int
	{
		guard let viewController = viewController as? ImageSlideViewController else { fatalError("Unexpected view controller type in page view controller.") }
		guard let viewControllerIndex = indexOfProtocolObject(inSlideViewController: viewController) else { fatalError("View controller's data item not found.") }
		
		return viewControllerIndex
	}
	
	private func slideViewController(forPageIndex pageIndex: Int) -> ImageSlideViewController?
	{
		if let slides = slides, slides.count > 0
		{
			let slide = slides[pageIndex]
			
			if let cachedController = slidesViewControllerCache.object(forKey: slide.slideIdentifier() as AnyObject) as? ImageSlideViewController
			{
				return cachedController
			}
			else
			{
				guard let controller = self.storyboard?.instantiateViewController(withIdentifier: "ImageSlideViewController") as? ImageSlideViewController else { fatalError("Unable to instantiate a ImageSlideViewController.") }
				controller.slide = slide
				controller.enableZoom = enableZoom
                controller.willBeginZoom = self.willBeginZoom ?? { self.setNavigationBar(visible: false) }
                
                controller.customActivityIndicatorView = self.getCustomActivityIndicatorView?()
                controller.startAnimationActivityIndicator = self.startAnimationActivityIndicator
                controller.stopAnimationActivityIndicator = self.stopAnimationActivityIndicator
                
                controller.onImageError = self.onImageError
				
				slidesViewControllerCache.setObject(controller, forKey: slide.slideIdentifier() as AnyObject)
				
				return controller
			}
		}
		
		return nil
	}
	
	private func prepareAnimations()
	{
		stepAnimate = { step, viewController in
			
			if let viewController = viewController as? ImageSlideViewController
			{
				if step == 0
				{
					viewController.imageView?.layer.shadowRadius = 10
					viewController.imageView?.layer.shadowOpacity = 0.3
				}
				else
				{
					let alpha = CGFloat(1.0 - step)
					
					self.navigationController?.navigationBar.alpha = 0.0
					self.navigationController?.view.backgroundColor = UIColor.black.withAlphaComponent(max(0.2, alpha * 0.9))
					
					let scale = max(0.8, alpha)
					
					viewController.imageView?.center = self.panViewCenter
					viewController.imageView?.transform = CGAffineTransform(scaleX: scale, y: scale)
				}
			}
		}
		restoreAnimation = { viewController in
			
			if let viewController = viewController as? ImageSlideViewController
			{
				UIView.animate(withDuration: 0.2,
				                           delay: 0.0,
				                           options: .beginFromCurrentState,
				                           animations: {
											
											//self.presentingViewController?.view.transform = .identity
											
											viewController.imageView?.center = self.originPanViewCenter
											viewController.imageView?.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
											viewController.imageView?.layer.shadowRadius = 0
											viewController.imageView?.layer.shadowOpacity = 0
											
					}, completion: nil)
			}
		}
		dismissAnimation = {  viewController, panDirection, completion in
			
			if let viewController = viewController as? ImageSlideViewController
			{
				let velocity = panDirection.y
				
				UIView.animate(withDuration: 0.3,
				                           delay: 0.0,
				                           options: .beginFromCurrentState,
				                           animations: {
											
											//self.presentingViewController?.view.transform = .identity
											
											var frame = viewController.imageView?.frame ?? .zero
											frame.origin.y = (velocity > 0 ? self.view.frame.size.height*2 : -self.view.frame.size.height)
											viewController.imageView?.transform = .identity
											viewController.imageView?.frame = frame
											viewController.imageView?.alpha = 0.0
											
					}, completion: { completed in
						
						completion()
						
				})
			}
		}
	}
	
	private func updateSlideBasedUI()
	{
		if let title = currentSlide?.title
		{
			navigationItem.title = title
		}
	}
	
	// MARK: Gestures
	
	@objc private func tapGesture(gesture:UITapGestureRecognizer)
	{
		setNavigationBar(visible: navigationBarHidden == true);
	}
	
	@objc private func panGesture(gesture:UIPanGestureRecognizer)
	{
        guard let viewController: UIViewController = slideViewController(forPageIndex: currentIndex) else {
            return
        }
		
		switch gesture.state
		{
		case .began:
			//presentingViewController?.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
			
			originPanViewCenter = view.center
			panViewCenter = view.center
			
			stepAnimate(0, viewController)
			
		case .changed:
			let translation = gesture.translation(in: view)
			panViewCenter = CGPoint(x: panViewCenter.x + translation.x, y: panViewCenter.y + translation.y)
			
			gesture.setTranslation(.zero, in: view)
			
			let distanceX = abs(originPanViewCenter.x - panViewCenter.x)
			let distanceY = abs(originPanViewCenter.y - panViewCenter.y)
			let distance = max(distanceX, distanceY)
			let center = max(originPanViewCenter.x, originPanViewCenter.y)
			
			let distanceNormalized = max(0, min((distance / center), 1.0))
			
			stepAnimate(distanceNormalized, viewController)
			
		case .ended, .cancelled, .failed:
			let distanceY = abs(originPanViewCenter.y - panViewCenter.y)
			
			if (distanceY >= panDismissTolerance)
			{
				UIView.animate(withDuration: 0.3,
				                           delay: 0.0,
				                           options: .beginFromCurrentState,
				                           animations: { () -> Void in
											
											self.navigationController?.view.alpha = 0.0
					}, completion:nil)
				
				dismissAnimation(viewController, gesture.velocity(in: gesture.view), {
					
					self.dismiss(sender: nil, animated: false)
					
				})
			}
			else
			{
				UIView.animate(withDuration: 0.2,
				                           delay: 0.0,
				                           options: .beginFromCurrentState,
				                           animations: { () -> Void in
											
											self.navigationBarHidden = true
											self.navigationController?.navigationBar.alpha = 0.0
											self.navigationController?.view.backgroundColor = .black
											
					}, completion: nil)
				
				restoreAnimation(viewController)
			}
			
		default:
			break;
		}
	}
    
    @objc private func doubleTapped(gesture:UITapGestureRecognizer) {
        
        guard let viewController: ImageSlideViewController = slideViewController(forPageIndex: currentIndex),
              let scrollView: UIScrollView = viewController.scrollView else {
            return
        }
        
        switch gesture.state {
            case .ended:
                
                if scrollView.zoomScale == scrollView.minimumZoomScale {
                    
                    let locationPoint: CGPoint = gesture.location(in: scrollView)
                    let centerPoint: CGPoint = scrollView.center
                    
                    let point: CGPoint = CGPoint(x: locationPoint.x + 2 * (centerPoint.x - locationPoint.x),
                                                 y: locationPoint.y + 2 * (centerPoint.y - locationPoint.y))
                        
                    viewController.imageView?.center = point
                    scrollView.setZoomScale(viewController.doubleTabZoomScale,
                                            animated: true)
                    
                } else {
                    viewController.imageView?.center = scrollView.center
                    scrollView.setZoomScale(scrollView.minimumZoomScale,
                                            animated: true)
                }
                
            default:
                break
        }
    }

}
