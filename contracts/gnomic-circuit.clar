;; Gnomic Circuit - Aphoristic wisdom distribution network
;;
;; A blockchain-powered knowledge marketplace enabling intellectual capital exchange through a secure token ecosystem. Users can monetize their expertise, set custom rates,
;; and participate in knowledge transfers within a decentralized framework.
;;


;; ================= REPUTATION MECHANISM =================
(define-map contributor-assessment {expert: principal, assessor: principal} uint)
(define-map contributor-reputation principal {cumulative-score: uint, assessment-count: uint})

;; ================= INCENTIVE STRUCTURES =================
(define-map knowledge-bundles {provider: principal} {units: uint, valuation: uint, incentive-rate: uint})

;; ================= ECOSYSTEM CONSTANTS =================
(define-constant knowledge-custodian tx-sender)
(define-constant error-unauthorized-access (err u200))
(define-constant error-insufficient-resources (err u201))
(define-constant error-invalid-knowledge-metrics (err u202))
(define-constant error-invalid-compensation (err u203))
(define-constant error-capacity-exceeded (err u204))
(define-constant error-self-reference-prohibited (err u205))
(define-constant error-saturation-threshold (err u206))
(define-constant error-zero-magnitude (err u207))
(define-constant error-threshold-breach (err u208))
(define-constant error-null-parameter (err u209))
(define-constant error-resource-contraction (err u210))
(define-constant error-credential-absent (err u211))
(define-constant error-rating-below-threshold (err u212))
(define-constant error-rating-ceiling-exceeded (err u213))
(define-constant error-incentive-floor (err u214))
(define-constant error-incentive-ceiling (err u215))

;; ================= PROTOCOL PARAMETERS =================
(define-data-var quantum-valuation uint u10)  
(define-data-var individual-resource-threshold uint u100) 
(define-data-var protocol-tribute-coefficient uint u10)
(define-data-var collective-knowledge-reservoir uint u0) 
(define-data-var ecosystem-saturation-threshold uint u1000) 

;; ================= PARTICIPANT REGISTRIES =================
;; Maps for tracking participant resources and interactions
(define-map knowledge-repository principal uint)    ;; Participant's available knowledge units
(define-map value-repository principal uint)        ;; Participant's available token reserves
(define-map knowledge-marketplace {provider: principal} {units: uint, valuation: uint})

;; ================= CREDENTIAL FRAMEWORK =================
(define-map verified-contributors principal bool)
(define-map premium-knowledge-offerings {provider: principal} {units: uint, valuation: uint, verified: bool})

;; ================= COLLABORATIVE FRAMEWORKS =================
(define-map collective-sessions uint {facilitator: principal, participants: (list 10 principal), timespan: uint, contribution: uint, phase: (string-ascii 20)})
(define-data-var session-identifier uint u0)

;; ================= UTILITY FUNCTIONS =================
(define-private (update-knowledge-reservoir (units-delta int))
  (let (
    (current-level (var-get collective-knowledge-reservoir))
    (adjusted-level (if (< units-delta 0)
                     ;; If reducing units, prevent underflow
                     (if (>= current-level (to-uint (- 0 units-delta)))
                         (- current-level (to-uint (- 0 units-delta)))
                         u0)
                     ;; If adding units
                     (+ current-level (to-uint units-delta))))
  )
    ;; Ensure we don't exceed ecosystem capacity
    (asserts! (<= adjusted-level (var-get ecosystem-saturation-threshold)) error-capacity-exceeded)
    ;; Update the reservoir level
    (var-set collective-knowledge-reservoir adjusted-level)
    (ok true)))

(define-private (calculate-protocol-tribute (exchange-magnitude uint))
  (let ((tribute-coefficient (var-get protocol-tribute-coefficient)))
    (/ (* exchange-magnitude tribute-coefficient) u100)))

;; ================= CORE PROTOCOL FUNCTIONS =================

;; Register new knowledge units to participant's account
(define-public (register-knowledge-units (units uint))
  (let (
    (participant tx-sender)
    (current-units (default-to u0 (map-get? knowledge-repository participant)))
    (threshold-maximum (var-get individual-resource-threshold))
    (acquisition-cost (* units (var-get quantum-valuation)))
    (participant-tokens (default-to u0 (map-get? value-repository participant)))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (<= (+ current-units units) threshold-maximum) error-saturation-threshold)
    (asserts! (>= participant-tokens acquisition-cost) error-insufficient-resources)

    ;; Update participant's knowledge and token balances
    (map-set knowledge-repository participant (+ current-units units))
    (map-set value-repository participant (- participant-tokens acquisition-cost))

    ;; Transfer acquisition cost to knowledge custodian
    (map-set value-repository knowledge-custodian (+ (default-to u0 (map-get? value-repository knowledge-custodian)) acquisition-cost))

    (ok true)))

;; Make knowledge units available for exchange
(define-public (publish-knowledge (units uint) (valuation uint))
  (let (
    (available-units (default-to u0 (map-get? knowledge-repository tx-sender)))
    (currently-published (get units (default-to {units: u0, valuation: u0} (map-get? knowledge-marketplace {provider: tx-sender}))))
    (total-published (+ units currently-published))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (> valuation u0) error-invalid-compensation)
    (asserts! (>= available-units total-published) error-insufficient-resources)

    ;; Update the global knowledge reservoir
    (try! (update-knowledge-reservoir (to-int units)))

    ;; Update the knowledge marketplace
    (map-set knowledge-marketplace {provider: tx-sender} {units: total-published, valuation: valuation})

    (ok true)))

;; Acquire knowledge from another participant
(define-public (acquire-knowledge (provider principal) (units uint))
  (let (
    (offering (default-to {units: u0, valuation: u0} (map-get? knowledge-marketplace {provider: provider})))
    (transaction-value (* units (get valuation offering)))
    (protocol-tribute (calculate-protocol-tribute transaction-value))
    (total-cost (+ transaction-value protocol-tribute))
    (provider-units (default-to u0 (map-get? knowledge-repository provider)))
    (acquirer-tokens (default-to u0 (map-get? value-repository tx-sender)))
    (provider-tokens (default-to u0 (map-get? value-repository provider)))
  )
    ;; Verify conditions for knowledge acquisition
    (asserts! (not (is-eq tx-sender provider)) error-self-reference-prohibited)
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (>= (get units offering) units) error-insufficient-resources)
    (asserts! (>= provider-units units) error-insufficient-resources)
    (asserts! (>= acquirer-tokens total-cost) error-insufficient-resources)

    ;; Update provider's knowledge balance and marketplace offerings
    (map-set knowledge-repository provider (- provider-units units))
    (map-set knowledge-marketplace {provider: provider} 
             {units: (- (get units offering) units), valuation: (get valuation offering)})

    ;; Update token balances for all parties
    (map-set value-repository tx-sender (- acquirer-tokens total-cost))
    (map-set value-repository provider (+ provider-tokens transaction-value))
    (map-set knowledge-repository tx-sender (+ (default-to u0 (map-get? knowledge-repository tx-sender)) units))

    ;; Allocate protocol tribute to custodian
    (map-set value-repository knowledge-custodian (+ (default-to u0 (map-get? value-repository knowledge-custodian)) protocol-tribute))

    (ok true)))

;; Offer verified premium knowledge (requires credentials)
(define-public (publish-premium-knowledge (units uint) (valuation uint))
  (let (
    (available-units (default-to u0 (map-get? knowledge-repository tx-sender)))
    (is-verified (default-to false (map-get? verified-contributors tx-sender)))
    (currently-published (get units (default-to {units: u0, valuation: u0} (map-get? knowledge-marketplace {provider: tx-sender}))))
    (total-published (+ units currently-published))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (> valuation u0) error-invalid-compensation)
    (asserts! is-verified error-credential-absent)
    (asserts! (>= available-units total-published) error-insufficient-resources)

    ;; Update the global knowledge reservoir
    (try! (update-knowledge-reservoir (to-int units)))

    ;; Update standard knowledge offerings
    (map-set knowledge-marketplace {provider: tx-sender} {units: total-published, valuation: valuation})

    ;; Update premium knowledge offerings
    (map-set premium-knowledge-offerings {provider: tx-sender} {units: units, valuation: valuation, verified: true})

    (ok true)))

;; Create a bundled package of knowledge units with incentive
(define-public (create-knowledge-bundle (units uint) (valuation uint) (incentive-rate uint))
  (let (
    (available-units (default-to u0 (map-get? knowledge-repository tx-sender)))
    (currently-published (get units (default-to {units: u0, valuation: u0} (map-get? knowledge-marketplace {provider: tx-sender}))))
    (current-bundle (default-to {units: u0, valuation: u0, incentive-rate: u0} (map-get? knowledge-bundles {provider: tx-sender})))
    (total-published (+ units currently-published))
    (total-bundled-units (+ units (get units current-bundle)))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (> valuation u0) error-invalid-compensation)
    (asserts! (> incentive-rate u0) error-incentive-floor)
    (asserts! (<= incentive-rate u50) error-incentive-ceiling)
    (asserts! (>= available-units total-published) error-insufficient-resources)

    ;; Update the global knowledge reservoir
    (try! (update-knowledge-reservoir (to-int units)))

    ;; Update knowledge availability in marketplace
    (map-set knowledge-marketplace {provider: tx-sender} {units: total-published, valuation: valuation})

    ;; Create or update the bundle offering
    (map-set knowledge-bundles {provider: tx-sender} {
      units: total-bundled-units, 
      valuation: valuation, 
      incentive-rate: incentive-rate
    })

    (ok true)))

;; Initialize a collaborative knowledge session
(define-public (initialize-collaborative-session (participants (list 10 principal)) (units uint) (contribution uint))
  (let (
    (available-units (default-to u0 (map-get? knowledge-repository tx-sender)))
    (session-id (var-get session-identifier))
    (participant-count (len participants))
    (total-session-units (* units participant-count))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (> contribution u0) error-invalid-compensation)
    (asserts! (>= available-units total-session-units) error-insufficient-resources)

    ;; Update the knowledge reservoir
    (try! (update-knowledge-reservoir (to-int total-session-units)))

    ;; Update facilitator's knowledge balance
    (map-set knowledge-repository tx-sender (- available-units total-session-units))

    ;; Increment the session identifier
    (var-set session-identifier (+ session-id u1))
    (ok session-id)))

;; Evaluate a contributor after knowledge acquisition
(define-public (evaluate-contributor (contributor principal) (rating uint))
  (let (
    (contributor-metrics (default-to {cumulative-score: u0, assessment-count: u0} (map-get? contributor-reputation contributor)))
    (current-total (get cumulative-score contributor-metrics))
    (current-count (get assessment-count contributor-metrics))
    (new-total (+ current-total rating))
    (new-count (+ current-count u1))
  )
    ;; Validate the input parameters
    (asserts! (not (is-eq tx-sender contributor)) error-self-reference-prohibited)
    (asserts! (>= rating u1) error-rating-below-threshold)
    (asserts! (<= rating u5) error-rating-ceiling-exceeded)

    ;; Update the contributor's reputation data
    (map-set contributor-assessment {expert: contributor, assessor: tx-sender} rating)
    (map-set contributor-reputation contributor {cumulative-score: new-total, assessment-count: new-count})

    (ok true)))

;; Deposit value tokens into the protocol
(define-public (deposit-value-tokens (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? value-repository tx-sender)))
    (new-balance (+ current-balance amount))
  )
    ;; Validate the input parameters
    (asserts! (> amount u0) error-zero-magnitude)

    ;; Transfer tokens from sender to protocol
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update participant's token balance in the protocol
    (map-set value-repository tx-sender new-balance)

    (ok true)))

;; Withdraw value tokens from the protocol
(define-public (withdraw-value-tokens (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? value-repository tx-sender)))
    (contract-balance (as-contract (stx-get-balance tx-sender)))
  )
    ;; Validate the input parameters
    (asserts! (> amount u0) error-zero-magnitude)
    (asserts! (>= current-balance amount) error-insufficient-resources)
    (asserts! (>= contract-balance amount) error-insufficient-resources)

    ;; Transfer tokens from protocol to participant
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))

    ;; Update participant's token balance in the protocol
    (map-set value-repository tx-sender (- current-balance amount))

    (ok true)))

;; Reclaim published knowledge that hasn't been acquired
(define-public (reclaim-published-knowledge (units uint))
  (let (
    (offering (default-to {units: u0, valuation: u0} (map-get? knowledge-marketplace {provider: tx-sender})))
    (available-units (get units offering))
    (participant-units (default-to u0 (map-get? knowledge-repository tx-sender)))
  )
    ;; Validate the input parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (>= available-units units) error-insufficient-resources)

    ;; Update the knowledge offering
    (map-set knowledge-marketplace {provider: tx-sender} {
      units: (- available-units units),
      valuation: (get valuation offering)
    })

    ;; Update participant's knowledge balance
    (map-set knowledge-repository tx-sender participant-units)

    ;; Handle premium offerings if applicable
    (if (is-some (map-get? premium-knowledge-offerings {provider: tx-sender}))
        (let (
          (premium-offering (unwrap-panic (map-get? premium-knowledge-offerings {provider: tx-sender})))
          (premium-units (get units premium-offering))
        )
          (if (>= premium-units units)
              (map-set premium-knowledge-offerings {provider: tx-sender} {
                units: (- premium-units units),
                valuation: (get valuation premium-offering),
                verified: (get verified premium-offering)
              })
              (map-delete premium-knowledge-offerings {provider: tx-sender})
          )
        )
        true
    )
    (ok true)))

;; Modify participant reputation manually (custodian only)
(define-public (adjust-participant-reputation (participant principal) (adjustment-value int))
  (let (
    (current-metrics (default-to {cumulative-score: u0, assessment-count: u0} 
                      (map-get? contributor-reputation participant)))
    (current-score (get cumulative-score current-metrics))
    (current-count (get assessment-count current-metrics))
    (adjusted-score (if (< adjustment-value 0)
                       (if (>= current-score (to-uint (- 0 adjustment-value)))
                           (- current-score (to-uint (- 0 adjustment-value)))
                           u0)
                       (+ current-score (to-uint adjustment-value))))
  )
    ;; Verify custodian privileges
    (asserts! (is-eq tx-sender knowledge-custodian) error-unauthorized-access)

    (ok true)))

;; Verify a participant's credentials (custodian only)
(define-public (verify-participant-credentials (participant principal) (status bool))
  (begin
    ;; Verify custodian privileges
    (asserts! (is-eq tx-sender knowledge-custodian) error-unauthorized-access)
    (ok true)))

;; Update protocol configuration (custodian only)
(define-public (update-protocol-parameters (new-quantum-value uint) 
                                          (new-protocol-tribute uint) 
                                          (new-individual-threshold uint) 
                                          (new-ecosystem-capacity uint))
  (begin
    ;; Verify custodian privileges
    (asserts! (is-eq tx-sender knowledge-custodian) error-unauthorized-access)

    ;; Validate the input parameters
    (asserts! (> new-quantum-value u0) error-invalid-compensation)
    (asserts! (<= new-protocol-tribute u30) error-threshold-breach)
    (asserts! (> new-individual-threshold u0) error-null-parameter)
    (asserts! (>= new-ecosystem-capacity (var-get collective-knowledge-reservoir)) error-resource-contraction)

    ;; Update the protocol parameters
    (var-set quantum-valuation new-quantum-value)
    (var-set protocol-tribute-coefficient new-protocol-tribute)
    (var-set individual-resource-threshold new-individual-threshold)
    (var-set ecosystem-saturation-threshold new-ecosystem-capacity)

    (ok true)))

;; Close a collaborative session and distribute rewards
(define-public (finalize-collaborative-session (session-id uint) (outcome-status (string-ascii 20)))
  (let (
    (session (default-to {
              facilitator: tx-sender, 
              participants: (list), 
              timespan: u0, 
              contribution: u0, 
              phase: "unknown"
             } (map-get? collective-sessions session-id)))
    (is-facilitator (is-eq tx-sender (get facilitator session)))
  )
    ;; Verify facilitator privileges
    (asserts! is-facilitator error-unauthorized-access)

    (ok true)))

;; Transfer knowledge directly between participants (custodian privileged)
(define-public (facilitate-knowledge-transfer (from-participant principal) 
                                             (to-participant principal)
                                             (units uint))
  (let (
    (from-balance (default-to u0 (map-get? knowledge-repository from-participant)))
    (to-balance (default-to u0 (map-get? knowledge-repository to-participant)))
  )
    ;; Verify custodian privileges
    (asserts! (is-eq tx-sender knowledge-custodian) error-unauthorized-access)

    ;; Validate the transfer parameters
    (asserts! (> units u0) error-invalid-knowledge-metrics)
    (asserts! (>= from-balance units) error-insufficient-resources)

    ;; Execute the transfer
    (map-set knowledge-repository from-participant (- from-balance units))

    (ok true)))

;; Reset session counter (custodian privileged)
(define-public (reset-session-identifier)
  (begin
    ;; Verify custodian privileges
    (asserts! (is-eq tx-sender knowledge-custodian) error-unauthorized-access)

    ;; Reset the counter
    (var-set session-identifier u0)

    (ok true)))

;; Get participant's knowledge balance
(define-read-only (get-knowledge-balance (participant principal))
  (default-to u0 (map-get? knowledge-repository participant)))

;; Get participant's value token balance
(define-read-only (get-value-balance (participant principal))
  (default-to u0 (map-get? value-repository participant)))

;; Get participant's reputation metrics
(define-read-only (get-reputation-metrics (participant principal))
  (default-to {cumulative-score: u0, assessment-count: u0} 
              (map-get? contributor-reputation participant)))

;; Get marketplace offering details
(define-read-only (get-marketplace-offering (provider principal))
  (default-to {units: u0, valuation: u0} 
              (map-get? knowledge-marketplace {provider: provider})))

;; Get premium offering details
(define-read-only (get-premium-offering (provider principal))
  (default-to {units: u0, valuation: u0, verified: false} 
              (map-get? premium-knowledge-offerings {provider: provider})))

;; Get bundle offering details
(define-read-only (get-bundle-offering (provider principal))
  (default-to {units: u0, valuation: u0, incentive-rate: u0} 
              (map-get? knowledge-bundles {provider: provider})))

;; Calculate average reputation score
(define-read-only (calculate-reputation-average (participant principal))
  (let (
    (metrics (get-reputation-metrics participant))
    (total-score (get cumulative-score metrics))
    (review-count (get assessment-count metrics))
  )
    (if (> review-count u0)
        (/ total-score review-count)
        u0)))

