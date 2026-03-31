# What to Test — wevo TestFlight Beta

wevo records P256-signed agreements between two people, entirely on-device.

Core flow (2 devices recommended):
1. Create an Identity (Manage Keys → +)
2. Create a Space (Sidebar → +)
3. Exchange Identities as Contacts via AirDrop
4. Create a Propose → Export → AirDrop .wevo-propose to the other device
5. Recipient imports, signs with their Identity
6. Honor (complete) or Part (exit) to finalize

Before step 5, either party can Dissolve the Propose to cancel it.

Identity export requires biometric auth. Message body is local only.
