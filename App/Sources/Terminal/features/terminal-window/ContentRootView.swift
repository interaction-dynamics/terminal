import AppKit

/// Lays out title strip / tabs / terminal / input, and paints the translucent
/// background behind the title strip.
final class ContentRootView: NSView {
    var compactChrome = false
    weak var titleBar: TitleBarView?
    weak var tabBar: TabBarView?
    weak var sidebar: TabSidebarView?
    weak var menuButton: NSView?
    weak var terminal: NSView?
    weak var input: InputAreaView?
    weak var settings: NSView?
    weak var banner: UpdateBanner?
    /// Height of the title strip; 0 when the dropdown's sidebar takes the top.
    private var titleHeight: CGFloat = Theme.tabBarHeight

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let config = ConfigStore.shared.config
        let g = Theme.gearSize
        let side = config.tabsPosition != .top
        // The dropdown with a sidebar has no title strip: the sidebar starts at the top.
        let compact = compactChrome && side
        let titleH: CGFloat = compact ? 0 : Theme.tabBarHeight
        titleHeight = titleH
        titleBar?.isHidden = compact
        titleBar?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: titleH)
        // The menu button is always there: top-right of the title strip, or of
        // the dropdown's sidebar.
        menuButton?.frame = NSRect(x: bounds.width - g - 10, y: (titleH - g) / 2, width: g, height: g)

        var body = NSRect(x: 0, y: titleH, width: bounds.width, height: max(0, bounds.height - titleH))
        tabBar?.isHidden = side
        sidebar?.isHidden = !side
        sidebar?.compactHeader = compact
        titleBar?.showsTitle = side
        if side {
            let w = min(config.tabsWidth, bounds.width / 2)
            let left = config.tabsPosition == .left
            sidebar?.edge = config.tabsPosition
            let frame = NSRect(x: left ? 0 : bounds.width - w, y: titleH, width: w, height: body.height)
            sidebar?.frame = frame
            if compact, let header = sidebar?.headerRect {
                let edge = left ? 1.0 : 0
                menuButton?.frame = NSRect(x: frame.minX + header.maxX - g - 2 - edge, y: frame.minY + header.midY - g / 2, width: g, height: g)
            }
            body.size.width -= w
            if left { body.origin.x = w }
        } else {
            tabBar?.frame = NSRect(x: 0, y: 0, width: bounds.width - g - 20, height: titleH)
        }
        // The update banner sits at the top of the terminal area, above the
        // terminal or the Settings tab.
        if let banner, !banner.isHidden {
            let h = UpdateBanner.Tuning.height
            banner.frame = NSRect(x: body.minX, y: body.minY, width: body.width, height: h)
            body.origin.y += h
            body.size.height = max(0, body.size.height - h)
        }
        settings?.frame = body

        var inputH: CGFloat = 0
        if let input, !input.isHidden {
            inputH = input.preferredHeight
            input.frame = NSRect(x: body.minX, y: body.maxY - inputH, width: body.width, height: inputH)
        }
        terminal?.frame = NSRect(x: body.minX, y: body.minY, width: body.width, height: max(0, body.height - inputH))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // The terminal draws its own (translucent) background; paint the same
        // colour under the tab bar so it reads as one surface. The input area
        // paints its own.
        let theme = Theme.current
        guard titleHeight > 0 else { return }
        theme.chromeBackground.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: titleHeight).fill()
    }
}
