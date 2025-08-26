;; PharmaTrack System
;; Pharmaceutical supply chain tracking preventing counterfeit drugs and ensuring safety
;; A blockchain-based solution for transparent drug verification and supply chain management

;; Define the contract
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-drug-not-found (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-drug-already-exists (err u104))

;; Drug information structure
(define-map drugs
  { drug-id: (string-ascii 32) }
  {
    manufacturer: principal,
    drug-name: (string-ascii 64),
    batch-number: (string-ascii 32),
    manufacture-date: uint,
    expiry-date: uint,
    is-verified: bool,
    current-holder: principal,
    verification-timestamp: uint
  }
)

;; Authorized manufacturers map
(define-map authorized-manufacturers principal bool)

;; Track drug verification history
(define-map verification-history
  { drug-id: (string-ascii 32), verifier: principal }
  { timestamp: uint, status: bool }
)

;; Initialize contract and add first authorized manufacturer (contract owner)
(begin
  (map-set authorized-manufacturers contract-owner true)
)

;; Function 1: Register a new pharmaceutical product in the supply chain
(define-public (register-drug 
  (drug-id (string-ascii 32))
  (drug-name (string-ascii 64))
  (batch-number (string-ascii 32))
  (manufacture-date uint)
  (expiry-date uint))
  (begin
    ;; Ensure only authorized manufacturers can register drugs
    (asserts! (default-to false (map-get? authorized-manufacturers tx-sender)) err-unauthorized)
    
    ;; Validate input parameters
    (asserts! (> (len drug-id) u0) err-invalid-input)
    (asserts! (> (len drug-name) u0) err-invalid-input)
    (asserts! (> (len batch-number) u0) err-invalid-input)
    (asserts! (< manufacture-date expiry-date) err-invalid-input)
    
    ;; Ensure drug doesn't already exist
    (asserts! (is-none (map-get? drugs { drug-id: drug-id })) err-drug-already-exists)
    
    ;; Register the drug with initial verification
    (map-set drugs
      { drug-id: drug-id }
      {
        manufacturer: tx-sender,
        drug-name: drug-name,
        batch-number: batch-number,
        manufacture-date: manufacture-date,
        expiry-date: expiry-date,
        is-verified: true,
        current-holder: tx-sender,
        verification-timestamp: stacks-block-height
      }
    )
    
    ;; Record initial verification in history
    (map-set verification-history
      { drug-id: drug-id, verifier: tx-sender }
      { timestamp: stacks-block-height, status: true }
    )
    
    ;; Emit registration event
    (print {
      event: "drug-registered",
      drug-id: drug-id,
      manufacturer: tx-sender,
      drug-name: drug-name,
      batch-number: batch-number,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Function 2: Verify and track pharmaceutical product authenticity
(define-public (verify-drug (drug-id (string-ascii 32)))
  (let (
    (drug-info (unwrap! (map-get? drugs { drug-id: drug-id }) err-drug-not-found))
  )
    ;; Validate input
    (asserts! (> (len drug-id) u0) err-invalid-input)
    
    ;; Update verification status and current holder
    (map-set drugs
      { drug-id: drug-id }
      (merge drug-info {
        is-verified: true,
        current-holder: tx-sender,
        verification-timestamp: stacks-block-height
      })
    )
    
    ;; Record verification in history
    (map-set verification-history
      { drug-id: drug-id, verifier: tx-sender }
      { timestamp: stacks-block-height, status: true }
    )
    
    ;; Emit verification event
    (print {
      event: "drug-verified",
      drug-id: drug-id,
      verifier: tx-sender,
      manufacturer: (get manufacturer drug-info),
      drug-name: (get drug-name drug-info),
      batch-number: (get batch-number drug-info),
      manufacture-date: (get manufacture-date drug-info),
      expiry-date: (get expiry-date drug-info),
      verification-timestamp: stacks-block-height,
      is-authentic: true
    })
    
    ;; Return comprehensive drug information for verification
    (ok {
      drug-id: drug-id,
      manufacturer: (get manufacturer drug-info),
      drug-name: (get drug-name drug-info),
      batch-number: (get batch-number drug-info),
      manufacture-date: (get manufacture-date drug-info),
      expiry-date: (get expiry-date drug-info),
      is-verified: true,
      current-holder: tx-sender,
      verification-timestamp: stacks-block-height,
      is-authentic: true
    })
  )
)

;; Read-only functions for querying drug information
(define-read-only (get-drug-info (drug-id (string-ascii 32)))
  (map-get? drugs { drug-id: drug-id })
)

(define-read-only (is-manufacturer-authorized (manufacturer principal))
  (default-to false (map-get? authorized-manufacturers manufacturer))
)

(define-read-only (get-verification-history (drug-id (string-ascii 32)) (verifier principal))
  (map-get? verification-history { drug-id: drug-id, verifier: verifier })
)

;; Owner functions
(define-public (add-authorized-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-manufacturers manufacturer true)
    (print { event: "manufacturer-authorized", manufacturer: manufacturer })
    (ok true)
  )
)

(define-public (remove-authorized-manufacturer (manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-manufacturers manufacturer false)
    (print { event: "manufacturer-deauthorized", manufacturer: manufacturer })
    (ok true)
  )
)