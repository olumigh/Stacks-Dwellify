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

;; Rent the property
(define-public (rent-property (property-id uint))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (match (map-get? properties { property-id: property-id })
      property
        (let (
          (total-cost (+ (get rental-price property) (get security-deposit property)))
          (fee (/ (* (get rental-price property) (var-get platform-fee-percentage)) u100))
        )
          (begin
            (asserts! (var-get contract-initialized) err-not-initialized)
            (asserts! (get available property) err-already-rented)
            (asserts! (get is-available property) err-unavailable)
            (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-funds)
            (try! (stx-transfer? (get rental-price property) tx-sender (get owner property)))
            (try! (stx-transfer? fee tx-sender contract-owner))
            (try! (stx-transfer? (get security-deposit property) tx-sender (var-get escrow-address)))
            (ok (map-set properties
              { property-id: property-id }
              (merge property {
                available: false,
                tenant: (some tx-sender),
                lease-start-time: block-height
              })))))
      err-not-found)))

;; End the lease
(define-public (end-lease (property-id uint))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (match (map-get? properties { property-id: property-id })
      property
        (let ((tenant (get tenant property)))
          (begin
            (asserts! (or (is-eq tx-sender (get owner property)) (is-eq (some tx-sender) tenant)) err-unauthorized)
            (asserts! (>= block-height (+ (get lease-start-time property) (get rental-duration property))) err-lease-not-expired)
            (try! (as-contract (stx-transfer? (get security-deposit property) (var-get escrow-address) (unwrap-panic tenant))))
            (ok (map-set properties
              { property-id: property-id }
              (merge property {
                available: true,
                tenant: none,
                lease-start-time: u0
              })))))
      err-not-found)))

;; Extend lease
(define-public (extend-lease (property-id uint) (extension-duration uint))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (asserts! (> extension-duration u0) err-invalid-duration)
    (match (map-get? properties { property-id: property-id })
      property
        (begin
          (asserts! (is-eq (some tx-sender) (get tenant property)) err-not-tenant)
          (let (
            (new-end-time (+ (get lease-start-time property) (get rental-duration property) extension-duration))
            (extension-cost (* (get rental-price property) (/ extension-duration (get rental-duration property))))
            (fee (/ (* extension-cost (var-get platform-fee-percentage)) u100))
          )
            (begin
              (try! (stx-transfer? extension-cost tx-sender (get owner property)))
              (try! (stx-transfer? fee tx-sender contract-owner))
              (ok (map-set properties
                { property-id: property-id }
                (merge property {
                  rental-duration: (+ (get rental-duration property) extension-duration)
                }))))))
      err-not-found)))

;; Rate a property
(define-public (rate-property (property-id uint) (rating uint))
  (begin
    (asserts! (> property-id u0) err-invalid-property-id)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (match (map-get? properties { property-id: property-id })
      property
        (let (
          (user-rating (default-to { total-rating: u0, count: u0, last-rating-time: u0 } (map-get? user-ratings { user: tx-sender })))
        )
          (begin
            (asserts! (is-eq (some tx-sender) (get tenant property)) err-not-tenant)
            (asserts! (> block-height (+ (get last-rating-time user-rating) u144)) err-rating-cooldown) ;; 1 day cooldown
            (map-set properties
              { property-id: property-id }
              (merge property { rating: rating }))
            (ok (map-set user-ratings
              { user: tx-sender }
              {
                total-rating: (+ (get total-rating user-rating) rating),
                count: (+ (get count user-rating) u1),
                last-rating-time: block-height
              }))))
      err-not-found)))
;; Rate a user (can be tenant or owner)
(define-public (rate-user (user principal) (rating uint))
  (let (
    (user-rating (default-to { total-rating: u0, count: u0, last-rating-time: u0 } (map-get? user-ratings { user: user })))
  )
    (begin
      (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
      (asserts! (> block-height (+ (get last-rating-time user-rating) u144)) err-rating-cooldown) ;; 1 day cooldown
      (ok (map-set user-ratings
        { user: user }
        {
          total-rating: (+ (get total-rating user-rating) rating),
          count: (+ (get count user-rating) u1),
          last-rating-time: block-height
        })))))

;; Verify a user
(define-public (verify-user (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set user-verification { user: user } { verified: true }))))

;; Get property details
(define-read-only (get-property-details (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property (ok property)
    err-not-found))

;; Get user rating
(define-read-only (get-user-rating (user principal))
  (match (map-get? user-ratings { user: user })
    rating (ok (if (is-eq (get count rating) u0)
                 u0
                 (/ (get total-rating rating) (get count rating))))
    (ok u0)))

;; Get total properties
(define-read-only (get-total-properties)
  (ok (var-get total-properties)))

;; Get remaining lease time
(define-read-only (get-remaining-lease-time (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property
      (let (
        (tenant (get tenant property))
        (lease-start (get lease-start-time property))
        (duration (get rental-duration property))
      )
        (ok (if (is-some tenant)
              (if (> (+ lease-start duration) block-height)
                (- (+ lease-start duration) block-height)
                u0)
              u0)))
    err-not-found))

;; Check if the contract is initialized
(define-read-only (is-initialized)
  (ok (var-get contract-initialized)))

;; Check if a user is verified
(define-read-only (is-user-verified (user principal))
  (ok (default-to false (get verified (map-get? user-verification { user: user })))))

;; Update platform fee
(define-public (update-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= new-fee-percentage u0) (<= new-fee-percentage u100)) err-invalid-fee)
    (ok (var-set platform-fee-percentage new-fee-percentage))))

;; Update escrow address
(define-public (update-escrow-address (new-escrow principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set escrow-address new-escrow))))