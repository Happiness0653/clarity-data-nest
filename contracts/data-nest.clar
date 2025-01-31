;; DataNest Storage Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-bucket-exists (err u102))
(define-constant err-bucket-not-found (err u103))
(define-constant err-insufficient-payment (err u104))

;; Storage cost in STX per byte
(define-constant storage-cost-per-byte u1)

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
    (ok bucket-id)
  )
)

(define-public (store-data (bucket-id uint) (key (string-utf8 128)) (value (string-utf8 1024)))
  (let (
    (bucket (unwrap! (map-get? buckets { bucket-id: bucket-id }) err-bucket-not-found))
    (payment (* (len value) storage-cost-per-byte))
  )
    (asserts! (or
      (is-eq tx-sender (get owner bucket))
      (get can-write (default-to { can-read: false, can-write: false }
        (map-get? bucket-permissions { bucket-id: bucket-id, user: tx-sender })))
    ) err-not-authorized)
    (try! (stx-transfer? payment tx-sender contract-owner))
    (map-set bucket-data { bucket-id: bucket-id, key: key } { value: value })
    (ok true)
  )
)

(define-public (grant-permission
  (bucket-id uint)
  (user principal)
  (can-read bool)
  (can-write bool)
)
  (let ((bucket (unwrap! (map-get? buckets { bucket-id: bucket-id }) err-bucket-not-found)))
    (asserts! (is-eq tx-sender (get owner bucket)) err-not-authorized)
    (map-set bucket-permissions
      { bucket-id: bucket-id, user: user }
      { can-read: can-read, can-write: can-write }
    )
    (ok true)
  )
)

;; Read only functions
(define-read-only (get-bucket-info (bucket-id uint))
  (map-get? buckets { bucket-id: bucket-id })
)

(define-read-only (get-data (bucket-id uint) (key (string-utf8 128)))
  (let ((bucket (unwrap! (map-get? buckets { bucket-id: bucket-id }) err-bucket-not-found)))
    (asserts! (or
      (get is-public bucket)
      (is-eq tx-sender (get owner bucket))
      (get can-read (default-to { can-read: false, can-write: false }
        (map-get? bucket-permissions { bucket-id: bucket-id, user: tx-sender })))
    ) err-not-authorized)
    (map-get? bucket-data { bucket-id: bucket-id, key: key })
  )
)
