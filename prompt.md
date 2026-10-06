Redesign the Flutter UI of this Qur'anic Madrassa app with a highly professional, modern, clean, and production-ready design. for all windows

### UI/UX direction

Create a calm and elegant Islamic educational interface. The design should feel trustworthy, premium, simple, and easy to use for students, teachers (Cheikhs), and administrators.

Do NOT overload the interface with Islamic decorations, patterns, gradients, animations, shadows, or excessive cards. Use Islamic visual identity subtly through colors, typography, spacing, and small decorative details.

Prioritize:

* Excellent visual hierarchy
* Clean spacing and alignment
* Consistent typography
* Strong readability
* Simple navigation
* Responsive layouts
* Accessibility
* RTL support for Arabic
* Light and dark mode where appropriate
* Consistent components throughout the entire application

### Packages to use

Prefer these packages where they genuinely improve the UI:

* `flutter_screenutil` → responsive sizing and spacing
* `google_fonts` → professional typography
* `iconsax` → modern consistent icons
* `flutter_svg` → SVG logos/icons/illustrations
* `cached_network_image` → optimized remote images
* `shimmer` → lightweight loading skeletons
* `lottie` → ONLY for meaningful empty/loading/success states, not everywhere
* `animations` → subtle page and component transitions
* `gap` → clean and consistent spacing
* `smooth_page_indicator` → onboarding/carousel indicators when needed
* `carousel_slider` → only where a carousel genuinely improves the UX

Do not add packages just for visual effects. Reuse existing Flutter widgets whenever possible.

### Design system

Create a centralized design system instead of styling every screen independently.

Define:

* App colors
* Typography styles
* Border radius values
* Elevation/shadow levels
* Spacing system
* Icon sizes
* Button styles
* Input styles
* Card styles
* Bottom sheets
* Dialogs
* Navigation components

Use `ThemeData` and reusable custom widgets.

Avoid hardcoding colors, font sizes, paddings, and radii throughout individual screens.

### Visual style

Use:

* Soft neutral backgrounds
* One primary Islamic-inspired accent color
* High contrast text
* Subtle borders
* Very light shadows
* Moderate corner radius
* Clean cards
* Large readable headings
* Compact secondary information
* Clear primary actions

Avoid:

* Excessive gradients
* Huge decorative backgrounds
* Too many colors
* Excessive rounded containers
* Glassmorphism everywhere
* Heavy shadows
* Excessive animations
* Decorative Islamic patterns on every screen
* Too many icons
* Dense information
* Unnecessary floating buttons
* Nested cards inside cards

### Qur'an / Hifdh experience

The Qur'an memorization experience should be the visual priority.

Make it:

* Extremely readable
* Calm and distraction-free
* Easy to navigate
* Comfortable for long sessions
* Arabic/RTL-first
* Clear when displaying Surah, Ayah, Hizb, Juz, and memorization progress

Use typography appropriate for Arabic/Qur'anic content and keep Qur'anic text visually distinct from application UI text.

### Main screens

Design each screen according to its purpose rather than applying the same layout everywhere.

For example:

Dashboard:

* Welcome/header
* Today's memorization progress
* Current Hifdh objective
* Quick actions
* Group/class information
* Recent activity

Student:

* Hifdh progress
* Current assignment
* Previous memorization
* Attendance
* Group information
* Teacher contact

Cheikh/Teacher:

* Groups
* Students
* Attendance
* Hifdh monitoring
* Weekly objectives
* Student progress

Attendance:

* Simple and fast interaction
* Clear status indicators
* Minimal taps
* Avoid visually heavy tables on mobile

Do not put every available feature on the dashboard. Prioritize the most important actions and move secondary features into dedicated screens.

### Component architecture

Create reusable components such as:

* `AppCard`
* `AppButton`
* `AppTextField`
* `AppHeader`
* `SectionHeader`
* `ProgressCard`
* `StudentCard`
* `GroupCard`
* `AttendanceTile`
* `HifdhProgressCard`
* `EmptyState`
* `LoadingSkeleton`
* `AppBottomSheet`
* `AppDialog`

Components should be reusable and configurable rather than duplicated.

### Performance and storage

The application must remain lightweight.

Do NOT:

* Add large libraries unnecessarily
* Download unnecessary assets
* Duplicate images
* Store large static assets when an existing Flutter/icon solution is sufficient
* Add multiple packages providing the same functionality
* Use animations that continuously consume resources
* Load large images without optimization

Use `const` widgets wherever possible.

Use lazy lists (`ListView.builder`, etc.) for dynamic content.

Optimize network images with `cached_network_image`.

Keep animations short and subtle.

### Important implementation rule

Do not redesign the application by simply adding more UI elements.

The goal is:

Professional ≠ overloaded.

Use whitespace, hierarchy, typography, alignment, and consistency to create a premium appearance.

Before implementing a screen, ask:

1. What is the primary action?
2. What information is most important?
3. What can be removed?
4. Can an existing reusable component be used?
5. Is this element actually necessary?

The final result should look like a professionally designed production application, not a template filled with components.

Maintain the existing business logic, Supabase integration, navigation, models, and functionality unless a change is explicitly necessary for the UI.

Focus primarily on improving the visual design, UX, consistency, responsiveness, and component architecture.
