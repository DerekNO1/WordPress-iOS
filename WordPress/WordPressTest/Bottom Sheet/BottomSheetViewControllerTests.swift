//import XCTest
//import Nimble
//
//@testable import WordPress
//
//class BottomSheetViewControllerTests: XCTestCase {
//
//    /// - Add the given ViewController as a child View Controller
//    ///
//    func testAddTheGivenViewControllerAsAChildViewController() {
//        let viewController = BottomSheetPresentableViewController()
//        let bottomSheet = BottomSheetViewController(childViewController: viewController)
//
//        bottomSheet.viewDidLoad()
//
//        expect(bottomSheet.children).to(contain(viewController))
//    }
//
//    /// - Add the given ViewController view to the subviews of the Bottom Sheet
//    ///
//    func testAddGivenVCViewToTheBottomSheetSubviews() {
//        let viewController = BottomSheetPresentableViewController()
//        let bottomSheet = BottomSheetViewController(childViewController: viewController)
//
//        bottomSheet.viewDidLoad()
//
//        expect(bottomSheet.view.subviews.flatMap { $0.subviews }).to(contain(viewController.view))
//    }
//}
//
//private class BottomSheetPresentableViewController: UIViewController, BottomSheetPresentable {
//    var initialHeight: CGFloat = 0
//}
