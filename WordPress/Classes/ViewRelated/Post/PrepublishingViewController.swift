import UIKit
import WordPressAuthenticator

private struct PrepublishingOption {
    let id: PrepublishingIdentifier
    let title: String
}

private enum PrepublishingIdentifier {
    case schedule
    case visibility
    case tags
}

class PrepublishingViewController: UITableViewController {
    let post: Post

    private let completion: (AbstractPost) -> ()

    private let options: [PrepublishingOption] = [
        PrepublishingOption(id: .schedule, title: NSLocalizedString("Publish", comment: "Label for Publish")),
        PrepublishingOption(id: .visibility, title: NSLocalizedString("Visibility", comment: "Label for Visibility")),
        PrepublishingOption(id: .tags, title: NSLocalizedString("Tags", comment: "Label for Tags"))
    ]

    let publishButton: NUXButton = {
        let nuxButton = NUXButton()
        nuxButton.isPrimary = true
        nuxButton.setTitle(NSLocalizedString("Publish Now", comment: "Label for a button that publishes the post"), for: .normal)

        return nuxButton
    }()

    init(post: Post, completion: @escaping (AbstractPost) -> ()) {
        self.post = post
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = Constants.title

        setupPublishButton()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: WPTableViewCell = {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.reuseIdentifier) as? WPTableViewCell else {
                return WPTableViewCell.init(style: .value1, reuseIdentifier: Constants.reuseIdentifier)
            }
            return cell
        }()

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = .zero
        cell.layoutMargins = .zero

        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = options[indexPath.row].title

        switch options[indexPath.row].id {
        case .tags:
            configureTagCell(cell)
        case .visibility:
            configureVisibilityCell(cell)
        case .schedule:
            configureScheduleCell(cell)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch options[indexPath.row].id {
        case .tags:
            didTapTagCell()
        case .visibility:
            didTapVisibilityCell()
        case .schedule:
            didTapSchedule()
        }
    }

    // MARK: - Tags

    private func configureTagCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = post.tags
    }

    private func didTapTagCell() {
        let tagPickerViewController = PostTagPickerViewController(tags: post.tags ?? "", blog: post.blog)

        tagPickerViewController.onValueChanged = { [weak self] tags in
            if !tags.isEmpty {
                WPAnalytics.track(.prepublishingTagsAdded)
            }

            self?.post.tags = tags
            self?.tableView.reloadData()
        }

        navigationController?.pushViewController(tagPickerViewController, animated: true)
    }

    // MARK: - Visibility

    private func configureVisibilityCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = post.titleForVisibility
    }

    private func didTapVisibilityCell() {
        let visbilitySelectorViewController = PostVisibilitySelectorViewController(post)

        visbilitySelectorViewController.completion = { [weak self] option in
            self?.tableView.reloadData()

            // If tue user selects password protected, prompt for a password
            if option == AbstractPost.passwordProtectedLabel {
                self?.showPasswordAlert()
            } else {
                self?.navigationController?.popViewController(animated: true)
            }
        }

        navigationController?.pushViewController(visbilitySelectorViewController, animated: true)
    }

    // MARK: - Schedule

    var scheduleLabel: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        dateFormatter.timeZone = post.blog.timeZone as TimeZone

        if let dateCreated = post.dateCreated, !post.shouldPublishImmediately() {
            return dateFormatter.string(from: dateCreated)
        } else {
            return NSLocalizedString("Immediately", comment: "Label that indicates that the post will be immediately published");
        }
    }

    func configureScheduleCell(_ cell: WPTableViewCell) {
        cell.detailTextLabel?.text = scheduleLabel
    }

    func didTapSchedule() {
        let model = PublishSettingsViewModel(post: post)

        (navigationController as? PrepublishingNavigationController)?.presentedVC?.transition(to: .hidden)

        let schedulingCalendarViewController = SchedulingCalendarViewController()
        let vc = LightNavigationController(rootViewController: schedulingCalendarViewController)
        schedulingCalendarViewController.coordinator = DateCoordinator(date: model.date, timeZone: model.timeZone, dateFormatter: model.dateFormatter, dateTimeFormatter: model.dateTimeFormatter) { [weak self] date in

            (self?.navigationController as? PrepublishingNavigationController)?.presentedVC?.transition(to: .collapsed)

            self?.tableView.reloadData()
            if let a  = self?.tableView.indexPathForSelectedRow {
                self?.tableView.deselectRow(at: a, animated: true)
            }
        }

        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = self

        present(vc, animated: true)
    }

    // MARK: - Publish Button

    private func setupPublishButton() {
        let footer = UIView(frame: Constants.footerFrame)
        footer.addSubview(publishButton)
        footer.pinSubviewToSafeArea(publishButton, insets: Constants.nuxButtonInsets)
        publishButton.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = footer
        publishButton.addTarget(self, action: #selector(publish(_:)), for: .touchUpInside)
    }

    @objc func publish(_ sender: UIButton) {
        navigationController?.dismiss(animated: true) {
            self.completion(self.post)
        }
    }

    // MARK: - Password Prompt

    private func showPasswordAlert() {
        let passwordAlertController = PasswordAlertController(onSubmit: { [weak self] password in
            guard let password = password, !password.isEmpty else {
                self?.cancelPasswordProtectedPost()
                return
            }

            self?.post.password = password
            self?.navigationController?.popViewController(animated: true)
        }, onCancel: { [weak self] in
            self?.cancelPasswordProtectedPost()
        })

        passwordAlertController.show(from: self)
    }

    private func cancelPasswordProtectedPost() {
        post.status = .publish
        post.password = nil
        tableView.reloadData()
    }

    private enum Constants {
        static let reuseIdentifier = "wpTableViewCell"
        static let nuxButtonInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        static let footerFrame = CGRect(x: 0, y: 0, width: 100, height: 40)
        static let title = NSLocalizedString("Publishing To", comment: "Label that describes in which blog the user is publishing to")
    }
}

extension Blog {
    @objc var timeZone: NSTimeZone {
        let timeZoneName: String? = getOption(name: "timezone")
        let gmtOffSet: NSNumber? = getOption(name: "gmt_offset")
        let optionValue: NSString? = getOption(name: "time_zone")

        var timeZone: NSTimeZone!

        if let timeZoneName = timeZoneName, !timeZoneName.isEmpty {
            timeZone = NSTimeZone(name: timeZoneName)
        } else if let gmtOffSet = gmtOffSet?.floatValue {
            timeZone = NSTimeZone.init(forSecondsFromGMT: Int(gmtOffSet * 60 * 60))
        } else if let optionValue = optionValue {
            let timeZoneOffsetSeconds = Int(optionValue.floatValue * 60 * 60)
            timeZone = NSTimeZone.init(forSecondsFromGMT: timeZoneOffsetSeconds)
        }

        if timeZone == nil {
            timeZone = NSTimeZone(forSecondsFromGMT: 0)
        }

        return timeZone
    }
}

extension PrepublishingViewController: UIViewControllerTransitioningDelegate, UIAdaptivePresentationControllerDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let presentationController = HalfScreenPresentationController(presentedViewController: presented, presenting: presenting)
        presentationController.delegate = self
        return presentationController
    }

    func adaptivePresentationStyle(for: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return traitCollection.verticalSizeClass == .compact ? .overFullScreen : .none
    }
}
