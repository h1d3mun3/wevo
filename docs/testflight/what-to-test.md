# What to Test — wevo TestFlight Beta

## Overview

wevo lets you create and sign cryptographic agreements with another person using P256 ECDSA signatures.
All signing happens on-device via the Keychain. The server (wevo-space) is an optional sync layer.

---

## Before You Start

- **Two iOS devices are recommended** to test the full signing flow
- Face ID or Touch ID must be enabled (required for Identity export)
- A wevo-space server URL is needed for server sync (provided separately)
- You can use the app fully offline — server sync is optional

---

## Core Flow to Test

### 1. Create an Identity

**Manage Keys → + → enter a nickname → Create**

- Verify the Identity appears in the list with a fingerprint
- Try creating multiple Identities

### 2. Create a Space

**Sidebar + → enter a name and server URL → Add**

- Verify the Space appears in the sidebar
- Try omitting the URL (local-only mode)

### 3. Exchange Contacts via AirDrop

**[Device A]** Manage Keys → tap Identity → Share as Contact → AirDrop to Device B

**[Device B]** Accept `.wevo-contact` → verify it appears in Contacts list

- Confirm the fingerprint matches on both devices (out-of-band verification)

### 4. Create a Propose and Send It

**[Device A]** Open Space → Create Propose → select Identity, Counterparty, enter message → Create → Export → AirDrop `.wevo-propose` to Device B

- Verify status shows `proposed`
- Verify the message body is stored locally

### 5. Sign the Propose

**[Device B]** Accept `.wevo-propose` → select Space → tap Propose → Sign → select Identity

- Verify only the correct Identity (matching counterparty public key) is shown
- Verify status changes to `signed`

### 6. Honor / Part

**Either device** → tap Propose → Honor (or Part)

- Verify the Propose moves to the Completed tab
- Verify server sync works if a URL is configured

### 7. Identity Export / Import

Manage Keys → tap Identity → Export → authenticate with Face ID/Touch ID → AirDrop `.wevo-identity`

- Verify biometric authentication is required
- Verify the Identity is correctly restored on the receiving device

---

## Focus Areas

- AirDrop reliability for `.wevo-propose`, `.wevo-identity`, `.wevo-contact` files
- Correct Identity filtering during signing (only valid counterparty shown)
- Behavior when the server URL is unreachable (should degrade gracefully)
- iCloud sync across devices using the same Apple ID

---

## Known Limitations

- Single counterparty per Propose (two-party only in this version)
- Message body cannot be recovered if the `.wevo-propose` file is lost
- HTTP connections are allowed in this beta build (HTTPS will be enforced in production)
- Local data may be reset if a SwiftData schema migration occurs during the beta period

---

## How to Report Feedback

Please use the **TestFlight feedback** feature (shake the device or tap the feedback button in TestFlight).
For detailed bug reports, include the steps to reproduce and the device model / iOS version.
