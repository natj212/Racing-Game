(include "universe.scm")
(include "color.scm")
(use (prefix sdl2 sdl2:)
     (prefix sdl2-ttf ttf:))

(define render-circles (lambda (world sdl col)
			 (let* ([pos (hash-ref world 'circle-a 'pos)]
				[texture (hash-ref world 'circle-a 'image)]
				[vel (hash-ref world 'circle-a 'vel)])
			   (render-texture sdl texture (round (car pos)) (round (cdr pos)) col 30 30)
			   (hash-update world 'circle-a 'pos (lambda (x) 
							       (cons (+ (car x) (/ (car vel) 10))
								     (+ (cdr x) (/ (cdr vel) 10))))))))

(define render-track (lambda (world sdl)
		       (map (lambda (point)
			      (apply draw-line (cons sdl point)))
			    (hash-ref world 'track))))

(define tup-map (lambda (proc tup)
		  (cons (proc (car tup)) (proc (cdr tup)))))

(define reflection (lambda (vec line)
		     (define angle->vec (lambda (d l)
					  (cons (round (* l (cos d))) 
						(round (* l (sin d))))))

		     (let* ( [line-angle (atan (-(second line) (fourth line))
					       (- (first line) (third line)))]
			    [vec-angle (atan (cdr vec) (car vec))]
			    [vec-length (distance 0 0 (car vec) (cdr vec))]
			    [new-angle (- line-angle (abs (- line-angle vec-angle)))]
			    [final-angle (if (equal? (angle->vec new-angle vec-length)
						     (tup-map exact->inexact vec))
					   (+ line-angle (abs (- line-angle vec-angle)))
					   new-angle)])
		       ;(display vec) (display ":") (display (angle->vec final-angle vec-length)) (newline)
		       (angle->vec final-angle vec-length)
		       )))

(define pi 3.141592)

(define distance (lambda (x1 y1 x2 y2)
		   (sqrt (+ (expt (- x2 x1) 2) (expt (- y2 y1) 2)))))

(define project (lambda (line-seg point)
		  (define get-angle (lambda (x)
				      (if (= 0 (car x)) (/ pi 2)  (atan (/ (cdr x) (car x))))))
		  (let* ([line-b 
			   (cons (- (third line-seg) (first line-seg)) (- (fourth line-seg) (second line-seg)))]
			 [line-a (cons (- (car point) (first line-seg)) (- (cdr point) (second line-seg)))]
			 [theta (- (get-angle line-a) (get-angle line-b))]
			 [a1-length (* (distance 0 0 (car line-a) (cdr line-a)) (cos theta))]
			 [b-distance (distance 0 0 (car line-b) (cdr line-b))]
			 [b-hat (cons (/ (car line-b) b-distance) (/ (cdr line-b) b-distance))]
			 [a1 (cons (* (car b-hat) a1-length) (* (cdr b-hat) a1-length))]
			 [a2-start (cons (+ (car a1) (first line-seg)) (+ (cdr a1) (second line-seg)))])
		    (if (or (> a1-length b-distance) #f) #f
		      (map round (list (car a2-start) (cdr a2-start) (car point) (cdr point)))))))

(define bounce (lambda (world sdl)
		 (let* ( [res (map 
				(lambda (line) (let ([proj 
						       (project line 
								(hash-ref world 'circle-a 'pos))])
						 (cond [proj
							 (apply draw-line (cons sdl proj))
							 (list (>= 15 (apply distance proj)) line proj)]
						       [else #f])))
				(hash-ref world 'track))]
			[leftover (filter (lambda (x) (and x (car x))) res)])
		   (cond [(and (not (null? leftover))
			       (not (equal? (second (car leftover)) (hash-ref world 'circle-a 'bounce))))  
			  (hash-update (hash-update world 'circle-a 'bounce 
						    (lambda (x) (second (car leftover)))) 'circle-a 'vel 
				       (lambda (x) 
					 (reflection x 
						     (second (car leftover)))))]
			 [(null? leftover) (hash-update world 'circle-a 'bounce (lambda (x) #f)) ]
			 [else world]))))

(big-bang (init-world (lambda (sdl) (make-hash 
				      (trail '())
				      (track '((640 0 0 360) (640 0 1280 360) (1280 360 640 720)
							     (640 720 0 360)
							     (640 100 100 360) (640 100 1180 360) (1180 360 640 620)
							     (640 620 100 360)))
				      (circle-a (make-hash
						  (bounce #f)
						  (image (make-circle 30 sdl #f #f 
								      (lambda (a b)
									(or 
									  (and (> a b) (< (/ a 2) b) ) 
									  (> (/ a 10) b) ))))
						  (pos (cons 35 360))
						  (vel (cons 0 0))))
				      (color 0))) 1280 720)
	  (on-draw (lambda (world sdl) 
		     (let* ( [c (hue->rgb (floor (hash-ref world 'color)))])
		       (set-color sdl (invert c))
		       (render-track world sdl)
		       (bounce world sdl)
		       (let ([return
			       (bounce (render-circles 
					 (hash-update world 'color (lambda (x) (+ 0.1 x)))
					 sdl
					 (invert c)) sdl)])
			 (set-color sdl c) return))))
	  (on-key (lambda (world event) (let ([m (cond [(equal? event 'up) '(0 . -1)]
						       [(equal? event 'down) '(0 . 1)]
						       [(equal? event 'left) '(-1 . 0)]
						       [(equal? event 'right) '(1 . 0)]
						       [else '(0 . 0)])])
					  (if (hash-ref world 'circle-a 'bounce)
					    world
					  (hash-update world 'circle-a 'vel 
						       (lambda (vel) (cons (+ (car vel) (car m)) 
									   (+ (cdr vel) (cdr m))))))))))
