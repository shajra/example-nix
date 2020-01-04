(when (configuration-layer/package-usedp 'dante)

  ;;; public

  (when (configuration-layer/layer-usedp 'extn-spacemacs)
    (defun extn-haskell/set-dir-locals (targets &optional baselocals)
      "Set ‘dante-target’ and other directory local variables.

Setting directory-local variables with “.dir-local.el” files can be tedious.
With this function we can set them programmatically.

This function only specifies these variables only for ‘haskell-mode’. See
‘extn-spacemacs/set-dirs-locals’ for a more general function.

TARGETS is an alist associating directory names to the setting of
‘dante-target’. BASELOCALS is an alist of other directory-local settings to
include for all directories associated in TARGETS."
      (let ((dirlocals
             (cl-loop for (dir . target) in targets collect
                      `(,dir . ((dante-target . ,target))))))
        (extn-spacemacs/set-dirs-locals 'haskell-mode dirlocals baselocals))))

  (defun extn-haskell/dante-restart ()
    "‘direnv’-aware replacement for ‘dante-restart’.

We need to update the Direnv environment before restarting Dante, otherwise we
might not pick up the right binaries for Cabal or Ghc.

Also, this function does a flycheck on all relevant buffers.
"
    (interactive)
    (when (configuration-layer/package-usedp 'direnv)
      (direnv-update-environment))
    (dante-restart)
    (when (configuration-layer/package-usedp 'flycheck)
      (let ((cabal-file (dante-cabal-find-file)))
        (dolist (buffer (buffer-list))
          (with-current-buffer buffer
            (when (and dante-mode
                       flycheck-mode
                       (equal (dante-cabal-find-file) cabal-file))
              (flycheck-buffer)))))))

  (defun extn-haskell/dante-repl-if-file-upward (root files f)
    "Search ROOT and its parents for a file in FILES and call F with it.

We start with ROOT (typically the Haskell package's root), and test if it
contains a file whose base name is in FILES. If none is found, we try again
with ROOT's parent, until we reach the root of the file system. The return
value is a call to F passing in the first matching filepath. If no matching
file is found, nil is returned.

This is useful for defining functions for a custom function for
‘extn-haskell/dante-repl-types’."
    (cl-some
     (lambda (file)
       (let ((found (locate-dominating-file root file)))
         (when found (funcall f found))))
     files))

  (file-name-base "a/b/c.ext")

  (defun extn-haskell/dante-target-guess ()
    "If ROOT is a cabal file, we use it's file name as the guessed target,
which can be overridden with `dante-target'."
    (or dante-target
        (let ((cabal-file (dante-cabal-find-file)))
          (if (equal "cabal" (file-name-extension cabal-file))
              (file-name-base cabal-file)
            nil))))

  (defun extn-haskell/dante-stack-alt (d)
    (and (locate-dominating-file d "stack.yaml")
         (directory-files d t "\\.cabal$")))

  ;;; private

  (defun extn-haskell//setq-default-dante-repl (list)
    (setq-default
     dante-methods-alist (extn-haskell//dante-repl-alist list)
     dante-methods list))

  (defun extn-haskell//dante-repl-alist (list)
    (let*
        ((alist-old dante-methods-alist)
         (alist-new (append
                     `(,(extn-haskell//dante-repl-stack-alt)
                       ,(extn-haskell//dante-repl-new-alt)
                       ,(extn-haskell//dante-repl-nix-alt))
                     alist-old)))
      (seq-map (lambda (elem) (or (assoc elem alist-new) elem)) list)))

  (defun extn-haskell//dante-repl-stack-alt ()
    `(stack-alt
      extn-haskell/dante-stack-alt
      ("stack" "repl"
       (extn-haskell/dante-target-guess)
       "--ghci-options=-ignore-dot-ghci")))

  (defun extn-haskell//dante-repl-new-alt ()
    `(new-alt
      ,(lambda (d) (directory-files d t "\\.cabal$"))
      ("cabal" "new-repl"
       dante-target
       "--builddir=dist-newstyle/dante"
       "--ghc-options=-ignore-dot-ghci")))

  (defun extn-haskell//dante-repl-nix-alt ()
    `(nix-alt
      "shell.nix"
      ("nix-shell" "--pure" "--run"
       (concat
         "cabal new-repl "
         (or dante-target "")
         " --builddir=dist-newstyle/dante"
         " --ghc-options=-ignore-dot-ghci"))))

  (defun extn-haskell//hook-if-not-regex (hook)
    (extn-haskell//hook-regex-guarded '-none? hook))

  (defun extn-haskell//hook-if-regex (hook)
    (extn-haskell//hook-regex-guarded '-any? hook))

  (defun extn-haskell//hook-regex-guarded (g hook)
    (eval
     (lambda ()
       (when
           (and
            (buffer-file-name)
            (funcall g
                     (lambda (regex) (string-match-p regex buffer-file-name))
                     extn-haskell/dante-exclude-regexes))
         (funcall hook)))
     `((g . ,g) (hook . ,hook))))

(defun extn-haskell//mode-hooks ()
  '(haskell-mode-local-vars-hook
    literate-haskell-mode-local-vars-hook))
