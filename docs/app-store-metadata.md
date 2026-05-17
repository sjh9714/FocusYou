# Focus You App Store Metadata

Use this copy for App Store Connect localization fields for build `2.3.13 (38)`.

## English

**Name**  
Focus You

**Subtitle**  
Focus Timer & Site Blocker

**Promotional Text**  
Start a focus timer, block distractions, and return your Mac to normal when the session ends.

**Description**  
Focus You is a calm macOS menu bar focus timer for people who want fewer distractions without a heavy productivity system.

Start a focused session, choose the websites or apps that should stay out of the way, and let Focus You handle the rest. When the timer ends or you stop the session, blocking is released cleanly so your Mac returns to normal.

What Focus You helps with:
- Start a 25-minute focus session quickly from the dashboard or menu bar.
- Use free timer, Pomodoro, or Flowmodoro modes.
- Block distracting websites and apps during active focus sessions.
- Keep timer-only sessions available when you only need lightweight focus.
- Save block profiles and schedules for recurring routines.
- Review sessions, streaks, milestones, and focus history.
- Export local backups and diagnostics when you need support.

The Mac App Store build uses Apple sandboxing and Network Extension based blocking. It does not modify /etc/hosts, install privileged helpers, or ask for administrator access.

Focus You stores your focus data locally on your Mac. Diagnostic bundles and backups are created only when you explicitly choose those actions.

Focus You Pro unlocks higher limits and advanced focus tools through monthly or annual subscriptions. You can restore purchases from the subscription screen at any time.

**Keywords**  
focus,timer,pomodoro,blocker,productivity,distraction,website,mac,habit,deep work

**Support URL**  
https://github.com/jinhyuk9714/FocusYou/issues

**Privacy Policy URL**  
https://github.com/jinhyuk9714/FocusYou/blob/main/docs/privacy-policy.md

**Terms of Use**  
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Korean

**Name**  
Focus You

**Subtitle**  
집중 타이머와 사이트 차단

**Promotional Text**  
집중 타이머를 시작하고 방해 요소를 차단한 뒤, 세션이 끝나면 Mac을 원래 상태로 되돌립니다.

**Description**  
Focus You는 복잡한 생산성 시스템보다 조용하고 확실한 집중 흐름이 필요한 사람을 위한 macOS 메뉴바 집중 타이머입니다.

집중 세션을 시작하고, 방해가 되는 웹사이트나 앱을 선택하면 Focus You가 세션 동안 차단을 유지합니다. 타이머가 끝나거나 세션을 중지하면 차단을 깨끗하게 해제해 Mac을 원래 상태로 되돌립니다.

Focus You로 할 수 있는 일:
- 대시보드나 메뉴바에서 25분 집중 세션을 빠르게 시작
- 자유 타이머, 뽀모도로, 플로우모도로 모드 사용
- 집중 세션 중 방해 웹사이트와 앱 차단
- 차단 없이 가볍게 집중하는 타이머만 세션 사용
- 반복 루틴을 위한 차단 프로필과 스케줄 저장
- 세션 기록, 스트릭, 마일스톤, 집중 이력 확인
- 지원이 필요할 때 로컬 백업과 진단 번들 내보내기

Mac App Store 빌드는 Apple sandbox와 Network Extension 기반 차단을 사용합니다. /etc/hosts를 수정하거나, privileged helper를 설치하거나, 관리자 권한을 요청하지 않습니다.

Focus You는 집중 데이터를 사용자의 Mac에 로컬로 저장합니다. 진단 번들과 백업은 사용자가 명시적으로 선택할 때만 생성됩니다.

Focus You Pro는 월간 또는 연간 구독으로 더 높은 한도와 고급 집중 도구를 제공합니다. 구독 화면에서 언제든지 구매 복원을 사용할 수 있습니다.

**Keywords**  
집중,타이머,뽀모도로,차단,생산성,방해,웹사이트,맥,습관,딥워크

**Support URL**  
https://github.com/jinhyuk9714/FocusYou/issues

**Privacy Policy URL**  
https://github.com/jinhyuk9714/FocusYou/blob/main/docs/privacy-policy.md

**Terms of Use**  
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Subscription Metadata

| Product ID | Reference name | Display name EN | Display name KO | Type |
| --- | --- | --- | --- | --- |
| `com.sungjh.focusyou.pro.monthly` | Pro Monthly | Focus You Pro Monthly | Focus You Pro 월간 | Auto-renewable subscription, 1 month |
| `com.sungjh.focusyou.pro.annual` | Pro Annual | Focus You Pro Annual | Focus You Pro 연간 | Auto-renewable subscription, 1 year |
| `com.sungjh.focusyou.pro.lifetime` | Pro Lifetime | Focus You Pro Lifetime | Focus You Pro 평생 | Non-consumable; hide unless approved/returned by StoreKit |

## App Review Notes

```text
Focus You is a macOS menu bar focus timer that blocks distracting websites/apps during user-started focus sessions.

Network Extension purpose:
The Mac App Store build uses a content filter Network Extension/System Extension to block only the websites selected by the user for the active focus session. The App Store build does not modify /etc/hosts, does not install a privileged helper, and does not use sudo or administrator AppleScript.

Calendar permission:
Calendar access is optional and only used when the user enables Apple Calendar sync. Completed focus sessions can be written to the user's calendar.

File access:
User Selected File read/write is used only for explicit user actions in Settings > Diagnostics: data backup, diagnostic bundle export, backup preview, and selected backup import.

Subscriptions:
The app includes Pro subscription gates. Restore Purchases is available in the subscription/paywall flow.

Submitted product IDs:
- com.sungjh.focusyou.pro.monthly: monthly auto-renewable subscription
- com.sungjh.focusyou.pro.annual: annual auto-renewable subscription

The lifetime product com.sungjh.focusyou.pro.lifetime is hidden unless App Store Connect returns the product.

Review path:
1. Launch Focus You.
2. Complete onboarding or choose the timer-only path.
3. Open Settings > Advanced and confirm the App Store build uses Network Extension blocking only.
4. Create or select a block profile with a test website.
5. Start a focus session.
6. Approve the Network Extension/System Extension if macOS prompts.
7. Confirm the selected website is blocked during the session.
8. Stop or complete the session and confirm blocking is released.
9. Open Settings > Diagnostics and export a backup/diagnostic bundle to a user-selected folder.
10. Open the subscription flow, start a sandbox purchase, and verify Restore Purchases.
```
