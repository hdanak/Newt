" Vim syntax file
" Language: Newt
" Maintainer: Hike Danakian
" Latest Revision: 26 January 2012

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword newtKeyword package class my sub
syn keyword newtLoops for while until
syn keyword newtCond if unless

" Variables and Types
syn match newtVar "[$@%]\w\+"
syn match newtType "[$@%]\w\+\(:\w\+\)\+" contains=newtVar

" Literals
syn region newtString start='"' end='"'

" Operators
syn match newtOperSym "[<>=+-\*\\/]\|||\|&&\|\*\*"

" Comments
syn match newtComment "#+\_.*+#"

" Class blocks
syn keyword newtClassWord method field
syn region newtClassBlock start='class\_.*{' end='}' fold

syn match newtPackage "\w\+::\w\+"
syn match newtDelim "[;,]"
syn match newtFunct "\w\+"


let b:current_syntax = "newt"

hi def link newtKeyword Keyword
hi def link newtClassWord Keyword
hi def link newtComment Comment
hi def link newtVar Identifier
hi def link newtType Type
hi def link newtOperSym Operator
hi def link newtPackage Type
hi def link newtDelim Delimiter
hi def link newtFunct Function
hi def link newtCond Conditional
hi def link newtString String
