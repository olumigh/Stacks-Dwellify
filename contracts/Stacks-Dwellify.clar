;; Updated Rent and Lease Smart Contract

;; Define constants

;; Existing error constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-initialized (err u101))
(define-constant err-not-initialized (err u102))
(define-constant err-already-rented (err u103))
(define-constant err-not-rented (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-not-tenant (err u106))
(define-constant err-not-found (err u107))
(define-constant err-lease-not-expired (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-rating-cooldown (err u110))
(define-constant err-unavailable (err u111))
(define-constant err-unauthorized (err u112))
(define-constant err-invalid-fee (err u113))

;; New error constants
(define-constant err-invalid-price (err u114))
(define-constant err-invalid-deposit (err u115))
(define-constant err-invalid-duration (err u116))
(define-constant err-invalid-description (err u117))
(define-constant err-invalid-property-id (err u118))
(define-constant err-invalid-principal (err u119))

;; Define data variables
(define-data-var contract-initialized bool false)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee
(define-data-var total-properties uint u0)
(define-data-var escrow-address principal contract-owner)

;; Define data maps
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    rental-price: uint,
    security-deposit: uint,
    rental-duration: uint,
    description: (string-ascii 256),
    available: bool,
    tenant: (optional principal),
    lease-start-time: uint,
    rating: uint,
    is-available: bool
  }
)

(define-map user-ratings 
  { user: principal } 
  { 
    total-rating: uint, 
    count: uint,
    last-rating-time: uint
  }
)

(define-map user-verification
  { user: principal }
  { verified: bool }
)

;; Initialize contract
(define-public (initialize (fee-percentage uint) (escrow principal))
  (begin

    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get contract-initialized)) err-already-initialized)
    (asserts! (and (>= fee-percentage u0) (<= fee-percentage u100)) err-invalid-fee)
    (var-set platform-fee-percentage fee-percentage)
    (var-set escrow-address escrow)
    (var-set contract-initialized true)
    (ok true)))

;; Add a new property
(define-public (add-property (price uint) (deposit uint) (duration uint) (description (string-ascii 256)))
  (let ((new-property-id (+ (var-get total-properties) u1)))
    (begin
      (asserts! (var-get contract-initialized) err-not-initialized)
      (asserts! (> price u0) err-invalid-price)
      (asserts! (>= deposit u0) err-invalid-deposit)
      (asserts! (> duration u0) err-invalid-duration)
      (asserts! (> (len description) u0) err-invalid-description)
      (map-set properties
        { property-id: new-property-id }
        {
          owner: tx-sender,
          rental-price: price,
          security-deposit: deposit,
          rental-duration: duration,
          description: description,
          available: true,
          tenant: none,
          lease-start-time: u0,
          rating: u0,
          is-available: true
        }
      )
      (var-set total-properties new-property-id)
      (ok new-property-id))))

;; Update property details
(define-public (update-property (property-id uint) (price uint) (deposit uint) (duration uint) (description (string-ascii 256)))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (>= deposit u0) err-invalid-deposit)
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> (len description) u0) err-invalid-description)
    (match (map-get? properties { property-id: property-id })
      property 
        (begin
          (asserts! (is-eq (get owner property) tx-sender) err-owner-only)
          (asserts! (get available property) err-already-rented)
          (ok (map-set properties
            { property-id: property-id }
            (merge property {
              rental-price: price,
              security-deposit: deposit,
              rental-duration: duration,
              description: description
            }))))
      err-not-found)))

;; Toggle property availability
(define-public (toggle-property-availability (property-id uint))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (match (map-get? properties { property-id: property-id })
      property 
        (begin
          (asserts! (is-eq (get owner property) tx-sender) err-owner-only)
          (asserts! (get available property) err-already-rented)
          (ok (map-set properties
            { property-id: property-id }
            (merge property {
              is-available: (not (get is-available property))
            }))))
      err-not-found)))
