(defpackage jobs
  (:use #:CL #:rules)
  (:import-from alexandria #:copy-hash-table)
  (:export #:make-job
           #:run))

(in-package jobs)

;;;; Runtime receive event, then generate a job.

(defparameter *init-env-table* (make-hash-table :test 'equal))

(defparameter *jobs-pool* (cl-threadpool:make-threadpool 5 :name "jobs threads pool"))

(defclass job ()
  ((job-id
    :initarg :id
    :reader job-id)
   (env
    :initarg :env
    :accessor job-env)))

(defun make-job (&key (env *init-env-table*))
  (make-instance 'job
                 :id (random 1024)
                 :env (copy-hash-table env)
                 ))

(defmethod initialize-instance :after ((j job) &key)
  (setf (gethash "job-id" (job-env j)) (job-id j)
        (gethash "job-name" (job-env j)) (format nil "job-id-~a" (job-id j)))
  )

(defmethod run ((j job) filename &key (pool *jobs-pool*))
  (cl-threadpool:add-job
   pool
   (lambda ()
     (let* ((*job-env-table* (job-env j))
            (*job-show-log* (make-string-output-stream))
            )
       (let* ((job-name (gethash "job-name" *job-env-table*))
              (header (format nil
                              "(make-package ~s :use '(#:CL #:jobs #:rules)) (in-package ~s)"
                              job-name
                              job-name))
              (tailer (format nil
                              "(in-package jobs) (delete-package ~s)"
                              job-name))
              )
         (with-open-stream (head-s (make-string-input-stream header))
           (loop
             for expr = (read head-s nil)
             if expr
               do (eval expr)
             else
               return nil))
         (with-open-file (s filename)
           (loop
             for expr = (read s nil)
             if expr
               do (eval expr)
             else
               return nil))
         (with-open-stream (tail-s (make-string-input-stream tailer))
           (loop
             for expr = (read tail-s nil)
             if expr
               do (eval expr)
             else
               return nil))
         
         *job-show-log*)
       ))))

