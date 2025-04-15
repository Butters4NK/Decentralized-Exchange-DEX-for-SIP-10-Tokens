
;; Decentralized-Exchange


;; Define constants
(define-constant FEE_BPS 30) ;; 0.3% fee (30 basis points)
(define-constant FEE_DENOMINATOR 10000)

;; Data structures
(define-map pools { token-x: principal, token-y: principal } 
    { 
        reserve-x: uint, 
        reserve-y: uint, 
        liquidity: uint 
    }
)

;; Helper functions
(define-private (sqrt (y uint))
    (if (<= y 1)
        y
        (fold (lambda (x) (if (> (* x x) y) x (ok x))) 1 (map (lambda (i) (+ i 1)) (range 1 100)))
    )
)

;; Add liquidity
(define-public (add-liquidity (token-x principal) (token-y principal) (amount-x uint) (amount-y uint) (min-liquidity uint))
    (let (
        (pool-key { token-x: token-x, token-y: token-y })
        (pool (default-to { reserve-x: 0, reserve-y: 0, liquidity: 0 } (map-get? pools pool-key)))
        (total-liquidity (get liquidity pool))
        (reserve-x (get reserve-x pool))
        (reserve-y (get reserve-y pool))
    )
    
     )
        (asserts! (> liquidity 0) (err u2))
        (asserts! (>= liquidity min-liquidity) (err u3))
        (map-set pools pool-key {
            reserve-x: (+ reserve-x amount-x),
            reserve-y: (+ reserve-y amount-y),
            liquidity: (+ total-liquidity liquidity)
        })
        (ok liquidity)
        )
    )
))

;; Swap tokens
(define-public (swap-x-for-y (token-x principal) (token-y principal) (amount-in uint) (min-out uint))
    (let (
        (pool-key { token-x: token-x, token-y: token-y })
        (pool (unwrap! (map-get? pools pool-key) (err u4)))
        (reserve-x (get reserve-x pool))
        (reserve-y (get reserve-y pool))
        (amount-in-with-fee (* amount-in (- FEE_DENOMINATOR FEE_BP
        S)))
    )
    
    ;; Transfer input tokens
    (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
    
    ;; Calculate output
    (let ((numerator (* amount-in-with-fee reserve-y)))
        (denominator (+ (* reserve-x FEE_DENOMINATOR) amount-in-with-fee)))
        (amount-out (/ numerator denominator))
    )
    
    (asserts! (>= amount-out min-out) (err u5))
    
     ;; Update reserves
    (map-set pools pool-key {
        reserve-x: (+ reserve-x amount-in),
        reserve-y: (- reserve-y amount-out),
        liquidity: (get liquidity pool)
    })
    
    ;; Transfer output tokens
    (contract-call? token-y transfer amount-out (as-contract tx-sender) tx-sender)
)

;; Remove liquidity
(define-public (remove-liquidity (token-x principal) (token-y principal) (liquidity uint))
    (let (
        (pool-key { token-x: token-x, token-y: token-y })
        (pool (unwrap! (map-get? pools pool-key) (err u6)))
        (total-liquidity (get liquidity pool))
        (reserve-x (get reserve-x pool))
        (reserve-y (get reserve-y pool))
    )
    (asserts! (>= total-liquidity liquidity) (err u7))
    
    (let (
        (amount-x (/ (* reserve-x liquidity) total-liquidity))
        (amount-y (/ (* reserve-y liquidity) total-liquidity))
    )
    
    ;; Update pool
    (map-set pools pool-key {
        reserve-x: (- reserve-x amount-x),
        reserve-y: (- reserve-y amount-y),
        liquidity: (- total-liquidity liquidity)
    })
    
    ;; Return tokens to user
    (try! (contract-call? token-x transfer amount-x (as-contract tx-sender) tx-sender))
    (try! (contract-call? token-y transfer amount-y (as-contract tx-sender) tx-sender))
    
    (ok true)
))

;; Getters
(define-read-only (get-reserves (token-x principal) (token-y principal))
    (default-to { reserve-x: 0, reserve-y: 0, liquidity: 0 } 
        (map-get? pools { token-x: token-x, token-y: token-y }))
)

(define-read-only (get-pool-exists (token-x principal) (token-y principal))
    (is-ok (map-get? pools { token-x: token-x, token-y: token-y }))
)