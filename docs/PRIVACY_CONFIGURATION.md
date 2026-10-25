# Privacy configuration

## Policy

The offline policy is in `Tick/Views/PrivacyPolicyView.swift`. Keep its wording
and update date aligned with `docs/PRIVACY_POLICY.md`, the copy prepared for
public hosting. The policy is accessible from the Spaces toolbar even when there
are no Spaces, uses native scalable text and heading accessibility traits, and
does not load a remote web page.

Privacy contact: `donnoel@icloud.com`. The intended public policy URL is
`https://github.com/donnoel/Tick/blob/main/docs/PRIVACY_POLICY.md`, following
the owner's preference for a repository link. Verify that the exact policy is
publicly reachable after these files are pushed, then enter the URL in App Store
Connect. A local repository document is not evidence of a published policy URL.
This change does not configure App Store Connect privacy answers or submit a build.

## Manifest scope

| Target | Required-reason API | Reason | Source evidence |
| --- | --- | --- | --- |
| Ticks | UserDefaults | CA92.1 | `ContentView` and `ProjectsView` store app-only tab, Space, and sort preferences. |
| Ticks | FileTimestamp | C617.1 | `TickDataStore`, `TickWidgetActionStore`, and `TickCloudSyncStore` inspect modification dates of the app's own saved snapshots. |
| Widget | FileTimestamp | C617.1 | Shared `TickWidgetActionStore` and `TickCloudSyncStore` inspect app-group snapshot files. |
| Watch | UserDefaults | CA92.1 | `TickWatchViewModel` stores its selected Space in standard preferences. |

Each target has its own `PrivacyInfo.xcprivacy`. The app and widget use Xcode's
synchronized resource membership; the Watch resource is explicitly listed in
`Tick.xcodeproj/project.pbxproj`. TickCore's selected shared sources do not use
additional required-reason APIs. No shared-suite UserDefaults reason is declared:
sharing files through an App Group does not itself require that reason.

The manifests declare no tracking, no tracking domains, and no developer-collected
data types. This reflects the current implementation: app records synchronize
only through the user's private Apple iCloud storage; no developer-operated
collection endpoint or third-party analytics/advertising SDK is present. This
does **not** mean that data never leaves the device: private iCloud synchronization
and user-initiated sharing are described in the policy. Reassess these declarations
and App Store Connect answers if data becomes accessible to the developer or a
new service, diagnostics SDK, support flow, or sharing behavior is added.

Microphone and location purpose strings remain in the app's Info.plist. Privacy
manifests do not replace runtime permissions, the policy, or App Store Connect's
App Privacy questionnaire.

## Verification

Validate source manifests with `plutil -lint`. After building, inspect each
`PrivacyInfo.xcprivacy` in `Tick.app`, its embedded widget, and its embedded Watch
app; source files alone do not prove bundle inclusion. The UI test
`testPrivacyPolicyIsAvailableWithoutSpaces` checks opening, scrolling through,
and dismissing the policy without creating data or enabling CloudKit.

## Apple references

- [Privacy policy requirements](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Required-reason API manifests](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
