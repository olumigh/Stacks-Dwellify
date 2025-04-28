# Stacks-Dwellify - Rent and Lease Smart Contract

A Clarity smart contract for decentralized **property rental management** on the Stacks blockchain.  
This contract allows users to **add**, **update**, **rent**, **rate**, and **manage** properties, with support for escrow handling, platform fees, user verification, and safe rating systems.

---

## 📜 Features

- **Property Management**: Owners can list, update, and toggle availability of properties.
- **Escrow Mechanism**: Security deposits are safely handled through an escrow address.
- **Rental Operations**: Tenants can rent properties and extend lease terms.
- **Fee Handling**: Platform charges a customizable percentage fee on rental transactions.
- **User Ratings**: Both tenants and owners can be rated to build trust.
- **Property Ratings**: Properties themselves can be rated.
- **User Verification**: Contract owner can verify users.
- **Admin Controls**: Owner can update platform fees and escrow address.
- **Security Focused**: Includes numerous validations and cooldowns to prevent misuse.

---

## 📚 Data Structures

### Constants

| Name | Description |
|:-----|:------------|
| `contract-owner` | Owner of the contract (initial deployer). |
| Error constants | Various specific error codes for clarity and better UX. |

---

### Variables

| Variable | Type | Description |
|:---------|:-----|:------------|
| `contract-initialized` | `bool` | Tracks if the contract has been initialized. |
| `platform-fee-percentage` | `uint` | Platform's fee percentage for rentals. |
| `total-properties` | `uint` | Counter for total properties listed. |
| `escrow-address` | `principal` | Address where security deposits are stored. |

---

### Maps

| Map | Description |
|:----|:------------|
| `properties` | Mapping of `property-id` to property details (owner, price, deposit, description, etc.). |
| `user-ratings` | Tracks cumulative ratings and last rating time for users. |
| `user-verification` | Tracks whether a user is verified. |

---

## 🛠 Public Functions

### Contract Setup

- `initialize(fee-percentage, escrow)`  
  Initializes the contract. Can only be called once by the owner.

### Property Management

- `add-property(price, deposit, duration, description)`  
  Adds a new property listing.

- `update-property(property-id, price, deposit, duration, description)`  
  Updates the details of an existing property (only if not rented).

- `toggle-property-availability(property-id)`  
  Toggles a property's availability status.

### Rental Operations

- `rent-property(property-id)`  
  Tenant rents a property (pays price + deposit + platform fee).

- `end-lease(property-id)`  
  Ends a lease (by owner or tenant) and returns the deposit to tenant after lease duration.

- `extend-lease(property-id, extension-duration)`  
  Tenant can extend the lease by paying proportional extra rental and fees.

### Ratings

- `rate-property(property-id, rating)`  
  Tenant rates the property (1-5 scale). 1-day cooldown enforced.

- `rate-user(user, rating)`  
  Rate a user (tenant or owner) with a 1-day cooldown.

### Administration

- `verify-user(user)`  
  Verifies a user (only by the contract owner).

- `update-platform-fee(new-fee-percentage)`  
  Updates platform fee percentage (only by owner).

- `update-escrow-address(new-escrow)`  
  Updates escrow address (only by owner).

---

## 📖 Read-Only Functions

- `get-property-details(property-id)`  
  Returns the details of a property.

- `get-user-rating(user)`  
  Returns a user's average rating.

- `get-total-properties()`  
  Returns the total number of properties listed.

- `get-remaining-lease-time(property-id)`  
  Returns remaining lease time for a property.

- `is-initialized()`  
  Returns whether the contract is initialized.

- `is-user-verified(user)`  
  Returns whether a user is verified.

---

## 🚨 Error Codes

| Error | Code | Description |
|:------|:-----|:------------|
| Owner Only | `100` | Only the contract owner can call. |
| Already Initialized | `101` | Contract already initialized. |
| Not Initialized | `102` | Contract not yet initialized. |
| Already Rented | `103` | Property already rented. |
| Not Rented | `104` | Property not rented. |
| Insufficient Funds | `105` | Not enough STX to perform action. |
| Not Tenant | `106` | Caller is not the tenant. |
| Not Found | `107` | Property or user not found. |
| Lease Not Expired | `108` | Cannot end lease before expiry. |
| Invalid Rating | `109` | Rating must be between 1-5. |
| Rating Cooldown | `110` | You must wait 1 day between ratings. |
| Unavailable Property | `111` | Property is marked unavailable. |
| Unauthorized | `112` | Unauthorized access. |
| Invalid Fee | `113` | Fee must be between 0-100%. |
| Invalid Price/Deposit/Duration/Description | `114-117` | Validation failures for property fields. |
| Invalid Property ID | `118` | Property ID must be > 0. |
| Invalid Principal | `119` | Invalid principal provided. |

---

## Security Considerations

- Funds for rental and deposit are transferred immediately upon renting.
- Deposits are securely stored in a designated escrow address.
- Validations prevent:
  - Renting unavailable properties.
  - Unauthorized updates or lease termination.
  - Rapid-fire rating manipulation (via cooldowns).
- Only the contract owner can update critical configurations.

---

##  Deployment Instructions

1. Deploy the contract to your Stacks blockchain environment.
2. Immediately call `initialize` to set the platform fee and escrow address.
3. Begin interacting: adding properties, renting, rating, etc.

---

## Future Improvements (Suggestions)

- **Dispute Resolution**: Enable owner-tenant disputes to be resolved via smart contract arbitration.
- **Multi-Currency Support**: Accept stablecoins or other crypto assets for rental payment.
- **Insurance Features**: Offer optional insurance for property rentals.
- **Advanced Escrow Logic**: Allow partial deposit returns for minor damages.
- **Dynamic Pricing**: Allow owners to set prices dynamically over time.

---
