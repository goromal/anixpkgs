// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="intro.html"><strong aria-hidden="true">1.</strong> Andrew&#39;s Software</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="machines.html"><strong aria-hidden="true">2.</strong> Machine Management</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rfcs/rfcs.html"><strong aria-hidden="true">3.</strong> RFCs</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rfcs/002.oscd.html"><strong aria-hidden="true">3.1.</strong> Continuous OS Deployment</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/cpp.html"><strong aria-hidden="true">4.</strong> C++ Packages</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/manif-geom-cpp.html"><strong aria-hidden="true">4.1.</strong> manif-geom-cpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/aapis-cpp.html"><strong aria-hidden="true">4.2.</strong> aapis-cpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/mscpp.html"><strong aria-hidden="true">4.3.</strong> mscpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/quad-sim-cpp.html"><strong aria-hidden="true">4.4.</strong> quad-sim-cpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/ceres-factors.html"><strong aria-hidden="true">4.5.</strong> ceres-factors</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/signals-cpp.html"><strong aria-hidden="true">4.6.</strong> signals-cpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/gnc.html"><strong aria-hidden="true">4.7.</strong> gnc</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/secure-delete.html"><strong aria-hidden="true">4.8.</strong> secure-delete</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/sorting.html"><strong aria-hidden="true">4.9.</strong> sorting</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/crowcpp.html"><strong aria-hidden="true">4.10.</strong> crowcpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/rankserver-cpp.html"><strong aria-hidden="true">4.11.</strong> rankserver-cpp</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="cpp/mfn.html"><strong aria-hidden="true">4.12.</strong> mfn</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rust/rust.html"><strong aria-hidden="true">5.</strong> Rust Packages</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rust/manif-geom-rs.html"><strong aria-hidden="true">5.1.</strong> manif-geom-rs</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rust/xv-lidar-rs.html"><strong aria-hidden="true">5.2.</strong> xv-lidar-rs</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="rust/sunnyside.html"><strong aria-hidden="true">5.3.</strong> sunnyside</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/python.html"><strong aria-hidden="true">6.</strong> Python Packages</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/aapis-py.html"><strong aria-hidden="true">6.1.</strong> aapis-py</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/fqt.html"><strong aria-hidden="true">6.2.</strong> fqt</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/find_rotational_conventions.html"><strong aria-hidden="true">6.3.</strong> find_rotational_conventions</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/daily_tactical_server.html"><strong aria-hidden="true">6.4.</strong> daily_tactical_server</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/geometry.html"><strong aria-hidden="true">6.5.</strong> geometry</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/pyceres.html"><strong aria-hidden="true">6.6.</strong> pyceres</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/pyceres_factors.html"><strong aria-hidden="true">6.7.</strong> pyceres_factors</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/pysorting.html"><strong aria-hidden="true">6.8.</strong> pysorting</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/makepyshell.html"><strong aria-hidden="true">6.9.</strong> makepyshell</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/scrape.html"><strong aria-hidden="true">6.10.</strong> scrape</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/pysignals.html"><strong aria-hidden="true">6.11.</strong> pysignals</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/mesh-plotter.html"><strong aria-hidden="true">6.12.</strong> mesh-plotter</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/orchestrator.html"><strong aria-hidden="true">6.13.</strong> orchestrator</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/gmail-parser.html"><strong aria-hidden="true">6.14.</strong> gmail-parser</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/trafficsim.html"><strong aria-hidden="true">6.15.</strong> trafficsim</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-hello-world.html"><strong aria-hidden="true">6.16.</strong> flask-hello-world</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-url2mp4.html"><strong aria-hidden="true">6.17.</strong> flask-url2mp4</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-mp4server.html"><strong aria-hidden="true">6.18.</strong> flask-mp4server</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-mp3server.html"><strong aria-hidden="true">6.19.</strong> flask-mp3server</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-smfserver.html"><strong aria-hidden="true">6.20.</strong> flask-smfserver</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/flask-oatbox.html"><strong aria-hidden="true">6.21.</strong> flask-oatbox</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/rankserver.html"><strong aria-hidden="true">6.22.</strong> rankserver</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/stampserver.html"><strong aria-hidden="true">6.23.</strong> stampserver</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/easy-google-auth.html"><strong aria-hidden="true">6.24.</strong> easy-google-auth</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/rcdo.html"><strong aria-hidden="true">6.25.</strong> rcdo</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/task-tools.html"><strong aria-hidden="true">6.26.</strong> task-tools</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/photos-tools.html"><strong aria-hidden="true">6.27.</strong> photos-tools</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/wiki-tools.html"><strong aria-hidden="true">6.28.</strong> wiki-tools</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/book-notes-sync.html"><strong aria-hidden="true">6.29.</strong> book-notes-sync</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="python/goromail.html"><strong aria-hidden="true">6.30.</strong> goromail</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/bash.html"><strong aria-hidden="true">7.</strong> Bash Packages</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/aapis-grpcurl.html"><strong aria-hidden="true">7.1.</strong> aapis-grpcurl</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/aptest.html"><strong aria-hidden="true">7.2.</strong> aptest</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/authm.html"><strong aria-hidden="true">7.3.</strong> authm</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/abc.html"><strong aria-hidden="true">7.4.</strong> abc</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/getres.html"><strong aria-hidden="true">7.5.</strong> getres</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/mp3.html"><strong aria-hidden="true">7.6.</strong> mp3</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/mp4.html"><strong aria-hidden="true">7.7.</strong> mp4</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/png.html"><strong aria-hidden="true">7.8.</strong> png</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/svg.html"><strong aria-hidden="true">7.9.</strong> svg</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/ckfile.html"><strong aria-hidden="true">7.10.</strong> ckfile</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/color-prints.html"><strong aria-hidden="true">7.11.</strong> color-prints</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/dirgroups.html"><strong aria-hidden="true">7.12.</strong> dirgroups</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/dirgather.html"><strong aria-hidden="true">7.13.</strong> dirgather</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/playabc.html"><strong aria-hidden="true">7.14.</strong> playabc</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/manage-gmail.html"><strong aria-hidden="true">7.15.</strong> manage-gmail</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/gantter.html"><strong aria-hidden="true">7.16.</strong> gantter</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/local-ssh-proxy.html"><strong aria-hidden="true">7.17.</strong> local-ssh-proxy</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/la-quiz.html"><strong aria-hidden="true">7.18.</strong> la-quiz</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/play.html"><strong aria-hidden="true">7.19.</strong> play</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/budget_report.html"><strong aria-hidden="true">7.20.</strong> budget_report</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/md2pdf.html"><strong aria-hidden="true">7.21.</strong> md2pdf</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/notabilify.html"><strong aria-hidden="true">7.22.</strong> notabilify</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/fix-perms.html"><strong aria-hidden="true">7.23.</strong> fix-perms</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/make-title.html"><strong aria-hidden="true">7.24.</strong> make-title</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/pb.html"><strong aria-hidden="true">7.25.</strong> pb</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/code2pdf.html"><strong aria-hidden="true">7.26.</strong> code2pdf</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/cpp-helper.html"><strong aria-hidden="true">7.27.</strong> cpp-helper</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/py-helper.html"><strong aria-hidden="true">7.28.</strong> py-helper</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/rust-helper.html"><strong aria-hidden="true">7.29.</strong> rust-helper</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/mp4unite.html"><strong aria-hidden="true">7.30.</strong> mp4unite</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/git-cc.html"><strong aria-hidden="true">7.31.</strong> git-cc</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/git-shortcuts.html"><strong aria-hidden="true">7.32.</strong> git-shortcuts</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/setupws.html"><strong aria-hidden="true">7.33.</strong> setupws</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/listsources.html"><strong aria-hidden="true">7.34.</strong> listsources</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/pkgshell.html"><strong aria-hidden="true">7.35.</strong> pkgshell</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/devshell.html"><strong aria-hidden="true">7.36.</strong> devshell</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/providence.html"><strong aria-hidden="true">7.37.</strong> providence</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/providence-tasker.html"><strong aria-hidden="true">7.38.</strong> providence-tasker</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/fixfname.html"><strong aria-hidden="true">7.39.</strong> fixfname</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/nix-deps.html"><strong aria-hidden="true">7.40.</strong> nix-deps</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/nix-diffs.html"><strong aria-hidden="true">7.41.</strong> nix-diffs</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/anix-version.html"><strong aria-hidden="true">7.42.</strong> anix-version</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/anix-upgrade.html"><strong aria-hidden="true">7.43.</strong> anix-upgrade</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/anix-changelog-compare.html"><strong aria-hidden="true">7.44.</strong> anix-changelog-compare</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/flake-update.html"><strong aria-hidden="true">7.45.</strong> flake-update</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="bash/rcrsync.html"><strong aria-hidden="true">7.46.</strong> rcrsync</a></span></li></ol><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="java/java.html"><strong aria-hidden="true">8.</strong> Java Packages</a></span><ol class="section"><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="java/evil-hangman.html"><strong aria-hidden="true">8.1.</strong> evil-hangman</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="java/spelling-corrector.html"><strong aria-hidden="true">8.2.</strong> spelling-corrector</a></span></li><li class="chapter-item expanded "><span class="chapter-link-wrapper"><a href="java/simple-image-editor.html"><strong aria-hidden="true">8.3.</strong> simple-image-editor</a></span></li></ol></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split('#')[0].split('?')[0];
        if (current_page.endsWith('/')) {
            current_page += 'index.html';
        }
        const links = Array.prototype.slice.call(this.querySelectorAll('a'));
        const l = links.length;
        for (let i = 0; i < l; ++i) {
            const link = links[i];
            const href = link.getAttribute('href');
            if (href && !href.startsWith('#') && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The 'index' page is supposed to alias the first chapter in the book.
            if (link.href === current_page
                || i === 0
                && path_to_root === ''
                && current_page.endsWith('/index.html')) {
                link.classList.add('active');
                let parent = link.parentElement;
                while (parent) {
                    if (parent.tagName === 'LI' && parent.classList.contains('chapter-item')) {
                        parent.classList.add('expanded');
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', e => {
            if (e.target.tagName === 'A') {
                const clientRect = e.target.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                sessionStorage.setItem('sidebar-scroll-offset', clientRect.top - sidebarRect.top);
            }
        }, { passive: true });
        const sidebarScrollOffset = sessionStorage.getItem('sidebar-scroll-offset');
        sessionStorage.removeItem('sidebar-scroll-offset');
        if (sidebarScrollOffset !== null) {
            // preserve sidebar scroll position when navigating via links within sidebar
            const activeSection = this.querySelector('.active');
            if (activeSection) {
                const clientRect = activeSection.getBoundingClientRect();
                const sidebarRect = this.getBoundingClientRect();
                const currentOffset = clientRect.top - sidebarRect.top;
                this.scrollTop += currentOffset - parseFloat(sidebarScrollOffset);
            }
        } else {
            // scroll sidebar to current active section when navigating via
            // 'next/previous chapter' buttons
            const activeSection = document.querySelector('#mdbook-sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        const sidebarAnchorToggles = document.querySelectorAll('.chapter-fold-toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(el => {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define('mdbook-sidebar-scrollbox', MDBookSidebarScrollbox);


// ---------------------------------------------------------------------------
// Support for dynamically adding headers to the sidebar.

(function() {
    // This is used to detect which direction the page has scrolled since the
    // last scroll event.
    let lastKnownScrollPosition = 0;
    // This is the threshold in px from the top of the screen where it will
    // consider a header the "current" header when scrolling down.
    const defaultDownThreshold = 150;
    // Same as defaultDownThreshold, except when scrolling up.
    const defaultUpThreshold = 300;
    // The threshold is a virtual horizontal line on the screen where it
    // considers the "current" header to be above the line. The threshold is
    // modified dynamically to handle headers that are near the bottom of the
    // screen, and to slightly offset the behavior when scrolling up vs down.
    let threshold = defaultDownThreshold;
    // This is used to disable updates while scrolling. This is needed when
    // clicking the header in the sidebar, which triggers a scroll event. It
    // is somewhat finicky to detect when the scroll has finished, so this
    // uses a relatively dumb system of disabling scroll updates for a short
    // time after the click.
    let disableScroll = false;
    // Array of header elements on the page.
    let headers;
    // Array of li elements that are initially collapsed headers in the sidebar.
    // I'm not sure why eslint seems to have a false positive here.
    // eslint-disable-next-line prefer-const
    let headerToggles = [];
    // This is a debugging tool for the threshold which you can enable in the console.
    let thresholdDebug = false;

    // Updates the threshold based on the scroll position.
    function updateThreshold() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const windowHeight = window.innerHeight;
        const documentHeight = document.documentElement.scrollHeight;

        // The number of pixels below the viewport, at most documentHeight.
        // This is used to push the threshold down to the bottom of the page
        // as the user scrolls towards the bottom.
        const pixelsBelow = Math.max(0, documentHeight - (scrollTop + windowHeight));
        // The number of pixels above the viewport, at least defaultDownThreshold.
        // Similar to pixelsBelow, this is used to push the threshold back towards
        // the top when reaching the top of the page.
        const pixelsAbove = Math.max(0, defaultDownThreshold - scrollTop);
        // How much the threshold should be offset once it gets close to the
        // bottom of the page.
        const bottomAdd = Math.max(0, windowHeight - pixelsBelow - defaultDownThreshold);
        let adjustedBottomAdd = bottomAdd;

        // Adjusts bottomAdd for a small document. The calculation above
        // assumes the document is at least twice the windowheight in size. If
        // it is less than that, then bottomAdd needs to be shrunk
        // proportional to the difference in size.
        if (documentHeight < windowHeight * 2) {
            const maxPixelsBelow = documentHeight - windowHeight;
            const t = 1 - pixelsBelow / Math.max(1, maxPixelsBelow);
            const clamp = Math.max(0, Math.min(1, t));
            adjustedBottomAdd *= clamp;
        }

        let scrollingDown = true;
        if (scrollTop < lastKnownScrollPosition) {
            scrollingDown = false;
        }

        if (scrollingDown) {
            // When scrolling down, move the threshold up towards the default
            // downwards threshold position. If near the bottom of the page,
            // adjustedBottomAdd will offset the threshold towards the bottom
            // of the page.
            const amountScrolledDown = scrollTop - lastKnownScrollPosition;
            const adjustedDefault = defaultDownThreshold + adjustedBottomAdd;
            threshold = Math.max(adjustedDefault, threshold - amountScrolledDown);
        } else {
            // When scrolling up, move the threshold down towards the default
            // upwards threshold position. If near the bottom of the page,
            // quickly transition the threshold back up where it normally
            // belongs.
            const amountScrolledUp = lastKnownScrollPosition - scrollTop;
            const adjustedDefault = defaultUpThreshold - pixelsAbove
                + Math.max(0, adjustedBottomAdd - defaultDownThreshold);
            threshold = Math.min(adjustedDefault, threshold + amountScrolledUp);
        }

        if (documentHeight <= windowHeight) {
            threshold = 0;
        }

        if (thresholdDebug) {
            const id = 'mdbook-threshold-debug-data';
            let data = document.getElementById(id);
            if (data === null) {
                data = document.createElement('div');
                data.id = id;
                data.style.cssText = `
                    position: fixed;
                    top: 50px;
                    right: 10px;
                    background-color: 0xeeeeee;
                    z-index: 9999;
                    pointer-events: none;
                `;
                document.body.appendChild(data);
            }
            data.innerHTML = `
                <table>
                  <tr><td>documentHeight</td><td>${documentHeight.toFixed(1)}</td></tr>
                  <tr><td>windowHeight</td><td>${windowHeight.toFixed(1)}</td></tr>
                  <tr><td>scrollTop</td><td>${scrollTop.toFixed(1)}</td></tr>
                  <tr><td>pixelsAbove</td><td>${pixelsAbove.toFixed(1)}</td></tr>
                  <tr><td>pixelsBelow</td><td>${pixelsBelow.toFixed(1)}</td></tr>
                  <tr><td>bottomAdd</td><td>${bottomAdd.toFixed(1)}</td></tr>
                  <tr><td>adjustedBottomAdd</td><td>${adjustedBottomAdd.toFixed(1)}</td></tr>
                  <tr><td>scrollingDown</td><td>${scrollingDown}</td></tr>
                  <tr><td>threshold</td><td>${threshold.toFixed(1)}</td></tr>
                </table>
            `;
            drawDebugLine();
        }

        lastKnownScrollPosition = scrollTop;
    }

    function drawDebugLine() {
        if (!document.body) {
            return;
        }
        const id = 'mdbook-threshold-debug-line';
        const existingLine = document.getElementById(id);
        if (existingLine) {
            existingLine.remove();
        }
        const line = document.createElement('div');
        line.id = id;
        line.style.cssText = `
            position: fixed;
            top: ${threshold}px;
            left: 0;
            width: 100vw;
            height: 2px;
            background-color: red;
            z-index: 9999;
            pointer-events: none;
        `;
        document.body.appendChild(line);
    }

    function mdbookEnableThresholdDebug() {
        thresholdDebug = true;
        updateThreshold();
        drawDebugLine();
    }

    window.mdbookEnableThresholdDebug = mdbookEnableThresholdDebug;

    // Updates which headers in the sidebar should be expanded. If the current
    // header is inside a collapsed group, then it, and all its parents should
    // be expanded.
    function updateHeaderExpanded(currentA) {
        // Add expanded to all header-item li ancestors.
        let current = currentA.parentElement;
        while (current) {
            if (current.tagName === 'LI' && current.classList.contains('header-item')) {
                current.classList.add('expanded');
            }
            current = current.parentElement;
        }
    }

    // Updates which header is marked as the "current" header in the sidebar.
    // This is done with a virtual Y threshold, where headers at or below
    // that line will be considered the current one.
    function updateCurrentHeader() {
        if (!headers || !headers.length) {
            return;
        }

        // Reset the classes, which will be rebuilt below.
        const els = document.getElementsByClassName('current-header');
        for (const el of els) {
            el.classList.remove('current-header');
        }
        for (const toggle of headerToggles) {
            toggle.classList.remove('expanded');
        }

        // Find the last header that is above the threshold.
        let lastHeader = null;
        for (const header of headers) {
            const rect = header.getBoundingClientRect();
            if (rect.top <= threshold) {
                lastHeader = header;
            } else {
                break;
            }
        }
        if (lastHeader === null) {
            lastHeader = headers[0];
            const rect = lastHeader.getBoundingClientRect();
            const windowHeight = window.innerHeight;
            if (rect.top >= windowHeight) {
                return;
            }
        }

        // Get the anchor in the summary.
        const href = '#' + lastHeader.id;
        const a = [...document.querySelectorAll('.header-in-summary')]
            .find(element => element.getAttribute('href') === href);
        if (!a) {
            return;
        }

        a.classList.add('current-header');

        updateHeaderExpanded(a);
    }

    // Updates which header is "current" based on the threshold line.
    function reloadCurrentHeader() {
        if (disableScroll) {
            return;
        }
        updateThreshold();
        updateCurrentHeader();
    }


    // When clicking on a header in the sidebar, this adjusts the threshold so
    // that it is located next to the header. This is so that header becomes
    // "current".
    function headerThresholdClick(event) {
        // See disableScroll description why this is done.
        disableScroll = true;
        setTimeout(() => {
            disableScroll = false;
        }, 100);
        // requestAnimationFrame is used to delay the update of the "current"
        // header until after the scroll is done, and the header is in the new
        // position.
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                // Closest is needed because if it has child elements like <code>.
                const a = event.target.closest('a');
                const href = a.getAttribute('href');
                const targetId = href.substring(1);
                const targetElement = document.getElementById(targetId);
                if (targetElement) {
                    threshold = targetElement.getBoundingClientRect().bottom;
                    updateCurrentHeader();
                }
            });
        });
    }

    // Takes the nodes from the given head and copies them over to the
    // destination, along with some filtering.
    function filterHeader(source, dest) {
        const clone = source.cloneNode(true);
        clone.querySelectorAll('mark').forEach(mark => {
            mark.replaceWith(...mark.childNodes);
        });
        dest.append(...clone.childNodes);
    }

    // Scans page for headers and adds them to the sidebar.
    document.addEventListener('DOMContentLoaded', function() {
        const activeSection = document.querySelector('#mdbook-sidebar .active');
        if (activeSection === null) {
            return;
        }

        const main = document.getElementsByTagName('main')[0];
        headers = Array.from(main.querySelectorAll('h2, h3, h4, h5, h6'))
            .filter(h => h.id !== '' && h.children.length && h.children[0].tagName === 'A');

        if (headers.length === 0) {
            return;
        }

        // Build a tree of headers in the sidebar.

        const stack = [];

        const firstLevel = parseInt(headers[0].tagName.charAt(1));
        for (let i = 1; i < firstLevel; i++) {
            const ol = document.createElement('ol');
            ol.classList.add('section');
            if (stack.length > 0) {
                stack[stack.length - 1].ol.appendChild(ol);
            }
            stack.push({level: i + 1, ol: ol});
        }

        // The level where it will start folding deeply nested headers.
        const foldLevel = 3;

        for (let i = 0; i < headers.length; i++) {
            const header = headers[i];
            const level = parseInt(header.tagName.charAt(1));

            const currentLevel = stack[stack.length - 1].level;
            if (level > currentLevel) {
                // Begin nesting to this level.
                for (let nextLevel = currentLevel + 1; nextLevel <= level; nextLevel++) {
                    const ol = document.createElement('ol');
                    ol.classList.add('section');
                    const last = stack[stack.length - 1];
                    const lastChild = last.ol.lastChild;
                    // Handle the case where jumping more than one nesting
                    // level, which doesn't have a list item to place this new
                    // list inside of.
                    if (lastChild) {
                        lastChild.appendChild(ol);
                    } else {
                        last.ol.appendChild(ol);
                    }
                    stack.push({level: nextLevel, ol: ol});
                }
            } else if (level < currentLevel) {
                while (stack.length > 1 && stack[stack.length - 1].level > level) {
                    stack.pop();
                }
            }

            const li = document.createElement('li');
            li.classList.add('header-item');
            li.classList.add('expanded');
            if (level < foldLevel) {
                li.classList.add('expanded');
            }
            const span = document.createElement('span');
            span.classList.add('chapter-link-wrapper');
            const a = document.createElement('a');
            span.appendChild(a);
            a.href = '#' + header.id;
            a.classList.add('header-in-summary');
            filterHeader(header.children[0], a);
            a.addEventListener('click', headerThresholdClick);
            const nextHeader = headers[i + 1];
            if (nextHeader !== undefined) {
                const nextLevel = parseInt(nextHeader.tagName.charAt(1));
                if (nextLevel > level && level >= foldLevel) {
                    const toggle = document.createElement('a');
                    toggle.classList.add('chapter-fold-toggle');
                    toggle.classList.add('header-toggle');
                    toggle.addEventListener('click', () => {
                        li.classList.toggle('expanded');
                    });
                    const toggleDiv = document.createElement('div');
                    toggleDiv.textContent = '❱';
                    toggle.appendChild(toggleDiv);
                    span.appendChild(toggle);
                    headerToggles.push(li);
                }
            }
            li.appendChild(span);

            const currentParent = stack[stack.length - 1];
            currentParent.ol.appendChild(li);
        }

        const onThisPage = document.createElement('div');
        onThisPage.classList.add('on-this-page');
        onThisPage.append(stack[0].ol);
        const activeItemSpan = activeSection.parentElement;
        activeItemSpan.after(onThisPage);
    });

    document.addEventListener('DOMContentLoaded', reloadCurrentHeader);
    document.addEventListener('scroll', reloadCurrentHeader, { passive: true });
})();

