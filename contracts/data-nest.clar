;; DataNest Storage Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-bucket-exists (err u102))
(define-constant err-bucket-not-found (err u103))
(define-constant err-insufficient-payment (err u104))
(define-constant err-invalid-data (err u105))
(define-constant err-bucket-full (err u106))

;; Storage cost in STX per byte
(define-constant storage-cost-per-byte u1)
(define-constant max-bucket-size u1048576) ;; 1MB max per bucket

;; Data structures
(define-map buckets
  { bucket-id: uint }
  {
    owner: principal,
    name: (string-utf8 64),
    size: uint,
    created-at: uint,
    is-public: bool
  }
)

(define-map bucket-data
  { bucket-id: uint, key: (string-utf8 128) }
  { value: (string-utf8 1024) }
)

(define-map bucket-permissions
  { bucket-id: uint, user: principal }
  { can-read: bool, can-write: bool }
)

;; Data vars
(define-data-var next-bucket-id uint u1)

;; Events
(define-data-var last-event-id uint u0)

(define-private (emit-event (event-type (string-utf8 64)) (bucket-id uint))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (print { event-id: event-id, type: event-type, bucket: bucket-id, timestamp: block-height })
    (var-set last-event-id event-id)
  )
)

;; Public functions
(define-public (create-bucket (name (string-utf8 64)) (is-public bool))
  (let ((bucket-id (var-get next-bucket-id)))
    (asserts! (not (map-get? buckets { bucket-id: bucket-id })) err-bucket-exists)
    (map-set buckets
      { bucket-id: bucket-id }
      {
        owner: tx-sender,
        name: name,
        size: u0,
        created-at: block-height,
        is-public: is-public
      }
    )
    (var-set next-bucket-id (+ bucket-id u1))
    (emit-event "bucket-created" bucket-id)
    (ok bucket-id)
  )
)

(define-public (store-data (bucket-id uint) (key (string-utf8 128)) (value (string-utf8 1024)))
  (let (
    (bucket (unwrap! (map-get? buckets { bucket-id: bucket-id }) err-bucket-not-found))
    (value-len (len value))
    (payment (* value-len storage-cost-per-byte))
    (new-size (+ (get size bucket) value-len))
  )
    (asserts! (> value-len u0) err-invalid-data)
    (asserts! (<= new-size max-bucket-size) err-bucket-full)
    (asserts! (or
      (is-eq tx-sender (get owner bucket))
      (get can-write (default-to { can-read: false, can-write: false }
        (map-get? bucket-permissions { bucket-id: bucket-id, user: tx-sender })))
    ) err-not-authorized)
    (try! (stx-transfer? payment tx-sender contract-owner))
    (map-set bucket-data { bucket-id: bucket-id, key: key } { value: value })
    (map-set buckets { bucket-id: bucket-id }
      (merge bucket { size: new-size }))
    (emit-event "data-stored" bucket-id)
    (ok true)
  )
)

[... rest of the contract remains the same ...]
