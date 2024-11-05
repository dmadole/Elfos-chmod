
;  Copyright 2024, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


#include    include/bios.inc
#include    include/kernel.inc


          ; Unpublished kernel entry points

d_idewrite: equ   44ah
d_ideread:  equ   447h


          ; Executable program header

            org   2000h-6
            dw    start                 ; load address
            dw    end-start             ; memory size
            dw    initial               ; start address

start:      br    initial

            db    11+80h                ; month
            db    4                     ; day
            dw    2024                  ; year
            dw    1                     ; build

            db    'See github.com/dmadole/MiniDOS-chmod for more info',0


          ; As options are parsed, the bits to be cleared on the file will
          ; be cleared in R9 and the bits to be set wil be set in R9. Then
          ; R9.1 will and ANDed with the file bits and R9.0 will be ORed.

initial:    ldi   target.1              ; pointer to filename string
            phi   rf
            ldi   target.0
            plo   rf

            ldi   %11111111             ; initial state of no changes
            phi   r9
            ldi   %00000000
            plo   r9

            ldi   0                     ; option flags for -v and -d
            phi   rb

            lbr   skipspc               ; start with skipping initial space


          ; Loop back here between option blocks to verify the presence of,
          ; and skip any, intervening spaces.

nextopt:    sdi   'a'-' '               ; error if no space between options
            lbdf  dousage
 
skipspc:    lda   ra                    ; skip any leading spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipspc


          ; Check if is is a - option, if so parse all option letters and
          ; update R9 or RB.1 depending if a flag or mode option.

            sdi   ' '-'-'               ; if not a dash-introduced option
            lbnz  notdash

dashopt:    lda   ra                    ; if a dash but not -d option
            smi   'd'
            lbnz  notdopt

            ldi   1                     ; if -d then set mode 1
            lbr   setmode

notdopt:    smi   'v'-'d'               ; if a dash but not -v option
            lbnz  notvopt

            ldi   2                     ; if -v then set mode 2
setmode:    str   r2

            ghi   rb                    ; set mode bit for option
            or
            phi   rb

            lbr   dashopt               ; check for another dash option

notvopt:    smi   'x'-'v'               ; if a dash but not -x option
            lbnz  notxclr

            ldi   %11111101             ; if -x then clear flag 1
            lbr   anibits

notxclr:    smi   'w'-'x'               ; if a dash but not -w option
            lbnz  notwclr

            ldi   %11111011             ; if -w then clear flag 2
            lbr   anibits

notwclr:    smi   'h'-'w'               ; if a dash but not -h option
            lbnz  nothclr

            ldi   %11110111             ; if -h then clear flag 3
            lbr   anibits

nothclr:    smi   'a'-'h'               ; if a dash but not -a option
            lbnz  nextopt

            ldi   %11101111             ; if -a then clear flag 4
anibits:    str   r2

            ghi   r9                    ; clear bits in r9.1 and r9.0
            and
            phi   r9
            glo   r9
            and
            plo   r9

            lbr   dashopt               ; check for another dash option


          ; Check if it is a + option, if so parse all option letters that
          ; are presend and update the mode bits in r9.

notdash:    smi   '+'-'-'               ; if not a plus option either
            lbnz  endopts

plusopt:    lda   ra                    ; if a plus but not +x option
            smi   'x'
            lbnz  notxset

            ldi   %00000010             ; if +x option then set flag 1
            lbr   oribits

notxset:    smi   'w'-'x'               ; if a plus but not +w option
            lbnz  notwset

            ldi   %00000100             ; if +w option then set flag 2
            lbr   oribits

notwset:    smi   'h'-'w'               ; if a plus but not +h option
            lbnz  nothset

            ldi   %00001000             ; if +h option then set flag 3
            lbr   oribits

nothset:    smi   'a'-'h'               ; if a plus but not +a option
            lbnz  nextopt

            ldi   %00010000             ; if +a option then set flag 4
oribits:    str   r2

            ghi   r9                    ; set bits in r9.1 and r9.0
            or
            phi   r9
            glo   r9
            or
            plo   r9

            lbr   plusopt               ; check for another plus option


          ; If next character is not an option introducer, then it is the
          ; start of the pathname argument. While parsing the name, we also
          ; make a copy of it into our buffer so we can modify it.

endopts:    adi   '+'                   ; store first character of name
            str   rf

skipnam:    lda   ra                    ; skip over valid name characters
            lbz   gotname
            inc   rf
            str   rf
            sdi   ' '
            lbnf  skipnam

            dec   rf

skipend:    lda   ra                    ; skip over any trailing spaces
            lbz   gotname
            sdi   ' '
            lbdf  skipend


          ; Something wrong with command syntax, display some brief help.

dousage:    sep   scall                 ; error in syntax display help
            dw    o_inmsg
            db    'USAGE: chmod [-v] [-d] [+[x|w|h|a]|-[x|w|h|a]] ... path'
            db    13,10,0

            ldi   1                     ; return failure status
            sep   sret


          ; We have parsed the entire command line and have a pathname. If
          ; the pathname provided ends in slash, then set directory mode.

gotname:    ldn   rf                    ; skip if last character not slash
            smi   '/'
            lbnz  noslash

            ghi   rb                    ; set directory mode flag
            ori   1
            phi   rb

            lbr   termstr               ; terminate the pathname and start


          ; If the -d option was specified, then add a slash to the end of
          ; the pathname to make it a directory path.

noslash:    ghi   rb                    ; if in -d mode, add slash at end
            ani   1
            lbz   onefile

            inc   rf                    ; else add slash to end of path
            ldi   '/'
            str   rf

            lbr   termstr               ; terminate the pathname and start


          ; Otherwise, we are in single file mode. Find the trailing filename
          ; part of the pathname (after the last slash).

onefile:    ghi   rf                    ; get copy of pointer to end of name
            phi   ra
            glo   rf
            plo   ra


toslash:    ldn   ra                    ; if we reach the beginning then done
            lbz   atbegin

            smi   '/'                   ; if we reach a slash then done
            lbz   atslash

            dec   ra                    ; otherwise check the prior character
            lbr   toslash


          ; Check that the path provided is not actually a bare disk name
          ; reference like //0 because that's really a directory and we
          ; can't detect this case otherwise since it looks like a filename.

atslash:    dec   ra                    ; back up prior to found slash

            ldn   ra                    ; if at then beginning then ok
            lbz   notdisk

            smi   '/'                   ; if not two slashes then ook
            lbnz  notdisk

            dec   ra                    ; back up prior to second slash

            ldn   ra                    ; if at start then it's a disk path
            lbz   cantdir

            inc   ra                    ; otherwise restore name pointer
notdisk:    inc   ra
atbegin:    inc   ra


          ; Finally, terminate the name with a trailing zero

termstr:    inc   rf                    ; advance past last character

            ldi   0                     ; terminate with trailing zero
            str   rf


          ; We use O_OPENDIR as it's really the best way to get things done
          ; on Elf/OS 4 but there are a couple of issues. One is that it
          ; modifies R9 and RA, the other is that it returns a system file
          ; descriptor. On the latter, we will pass it one so that later
          ; versions needing that work correctly, but we run with whatever
          ; O_OPENDIR leaves in RD so it works with unfixed versions also.
          ; It's too bad about R9 and RA but we will just save and restore.

            ldi   fildes.1              ; pointer to file descriptor
            phi   rd
            ldi   fildes.0
            plo   rd

            ldi   target.1              ; pointer to the pathname
            phi   rf
            ldi   target.0
            plo   rf 

            glo   r9                    ; elfos 4 opendir modifies r9 and ra
            stxd
            ghi   r9
            stxd
            glo   ra
            stxd
            ghi   ra
            stxd

            sep   scall                 ; open the target directory
            dw    o_opendir

            irx                         ; restore r9 and ra after opendir
            ldxa
            phi   ra
            ldxa
            plo   ra
            ldxa
            phi   r9
            ldx
            plo   r9

            lbnf  diropen               ; if open succeeded go process

            sep   scall                 ; else display failure message
            dw    o_inmsg
            db    'ERROR: Unable to open file',13,10,0

            ldi   1                     ; return error status
            sep   sret


          ; Now that the appropriate directory is opern successfully, we
          ; will loop through it either processing all entries that are
          ; files if in directory mode, or looking for the specific named
          ; file to process if we are not.
          ;
          ; If we read full 32 byte directory entries, then after reading
          ; the last entry of each sector, the offset will be at the first
          ; byte of the next sector, meaning the next sector will have been
          ; preloaded into the DTA. If we then have to seek back to overwrite
          ; it, the prior sector will have to be loaded into the DTA again.
          ;
          ; Instead of that inefficiency, we will instead read 31 bytes the
          ; first time, since the alst byte can always be treated as zero,
          ; which is preloaded at the end of our buffer. Then we will read 32
          ; bytes each after that so we never advance into the next entry
          ; (and therefore the next sector) until we actually need to.

diropen:    ldi   diraddr.1             ; first time read into beginning
            phi   rf
            ldi   diraddr.0
            plo   rf

            ldi   dirlast-diraddr       ; first time only read 31 bytes


          ; Loop back to here to read each successive directory entry.

readent:    plo   rc                    ; set the dirent read length
            ldi   0
            phi   rc

            sep   scall                 ; read the entry from directory
            dw    o_read
            lbdf  readerr

            glo   rc                    ; end of file if less than 31
            smi   31
            lbnf  endfile

            ldi   diraddr.1             ; pointer to directory entry
            phi   rf
            ldi   diraddr.0
            plo   rf

            inc   rf                    ; check that it is not empty
            inc   rf
            lda   rf
            lbnz  isinuse
            ldn   rf
            lbz   nextent


isinuse:    ldi   dirflag.1             ; get pointer to flags byte
            phi   r7
            ldi   dirflag.0
            plo   r7


          ; In directory mode, we will process all entries in the directory,
          ; otherwise we need to search for only the named one.

            ghi   rb                    ; if we are in directory mode
            ani   1
            lbnz  allmode


         ; Not in directory mode, so match the filename specified with that
         ; in the directory entry for a match. If no match, get next entry.

            ldi   dirname.1         ; skip to filename field
            phi   rf
            ldi   dirname.0
            plo   rf

            ghi   ra                    ; get copy of filename pointer
            phi   rc
            glo   ra
            plo   rc

            sex   rf                    ; compare filename to dirent

strcomp:    lda   rc                    ; stop if at end of filename
            lbz   endstr

            sm                          ; else loop as long as match
            inc   rf
            lbz   strcomp

            sex   r2                    ; next entry if character mismatch
            lbr   nextent

endstr:     sex   r2                    ; next entry if length not the same
            ldn   rf
            lbnz  nextent


          ; For now, we don't change flags on directories, so check the file
          ; first, and if not a directory then update the flags.

            ldn   r7                    ; if not a directory then update
            ani   1
            lbz   chgflag


          ; If the target file is a directory then exit with failure.

cantdir:    sep   scall                 ; display error message
            dw    o_inmsg
            db    'ERROR: target is a directory',13,10,0

            ldi   1                     ; return exit status
            sep   sret


          ; If in directory mode, we will process all files in the specified
          ; directory. Check the entry and if it's a directory then skip it.

allmode:    ldn   r7                    ; skip entry if its a directory
            ani   1
            lbnz  nextent


          ; We are now ready to update the flags in the directory entry .
          ; After cleaing and setting flags, check if anything actually
          ; changed and if not, do not print the name or write back.

chgflag:    ldn   r7                    ; save flags byte from dirent
            str   r2

            ghi   r9                    ; clear zero bits from r9.1
            and
            str   r2

            glo   r9                    ; set one bits from r9.0
            or
            str   r2

            ldn   r7                    ; if no changes, do nothing
            xor
            lbz   nothing


          ; We actually made changes, so print the filename if in verbose
          ; mode and then write the update back into the directory entry.

            ldn   r2                    ; save changes back to dirent
            str   r7

            ghi   rb                    ; if not verbose skip print
            ani   2
            lbz   notverb

            ldi   target.1              ; get pointer to target name
            phi   rf
            ldi   target.0
            plo   rf

            sep   scall                 ; output the target name
            dw    o_msg


          ; If we are in directory mode, then the target name above is only
          ; the directory part, now we need to append the filename part.

            ghi   rb                    ; filename only if directory mode
            ani   1
            lbz   notfile

            ldi   dirname.1             ; get pointer to filename
            phi   rf
            ldi   dirname.0
            plo   rf

            sep   scall                 ; output the filename
            dw    o_msg

notfile:    sep   scall                 ; output newline and return
            dw    o_inmsg
            db    13,10,0


          ; Now write the entry back into the directory. We back up 25 bytes
          ; to reach the flags field, and then write out 25 bytes to update
          ; the flags and restore the offset back to the same position.

notverb:    ldi   (dirflag-dirlast).1   ; go backwards 25 bytes to flags
            phi   r8
            plo   r8
            phi   r7
            ldi   (dirflag-dirlast).0
            plo   r7

            ldi   1                     ; seek relative to current offset
            plo   rc

            sep   scall
            dw    o_seek
            lbdf  readerr

            ldi   dirflag.1             ; pointer to dirent flags byte
            phi   rf
            ldi   dirflag.0
            plo   rf

            ldi   (dirlast-dirflag).1   ; write 25 bytes to end of dirent
            phi   rc
            ldi   (dirlast-dirflag).0
            plo   rc

            sep   scall                 ; write back over the dirent
            dw    o_write
            lbdf  writerr


          ; If we found a matching entry in file mode, then we are done as
          ; there will only be one match, so exit with success even if we
          ; didn't actually change anything.

nothing:    ghi   rb                    ; finished if not in directory mode
            ani   1
            lbz   success


          ; Otherwise, if we are in directory mode, or in in file mode but
          ; we didn't match yet, proceed to the next directory entry.

nextent:    ldi   dirprev.1             ; get pointer to dirent buffer
            phi   rf
            ldi   dirprev.0
            plo   rf

            ldi   dirlast-dirprev       ; read next entry of 32 bytes
            lbr   readent

 
          ; If we reached end of file in directory mode, that is a normal
          ; exit condition, otherwise it means we didn't file the file.

endfile:    ghi   rb                    ; if directory mode then success
            ani   1
            lbnz  success

            sep   scall                 ; else display error message
            dw    o_inmsg
            db    'ERROR: file not found',13,10,0

            sep   scall                 ; close directory file
            dw    o_close

            ldi   1                     ; and return failure
            sep   sret


          ; If we were not in directory mode and we found the file, then
          ; return success.

success:    sep   scall                 ; close directory file
            dw    o_close

            ldi   0                     ; return success status
            sep   sret


          ; If an error occurs reading or seeking the file, give up.

readerr:    sep   scall                 ; display failure message
            dw    o_inmsg
            db    'ERROR: unable to read directory',13,10,0

            sep   scall                 ; attempt to close file anyway
            dw    o_close

            ldi   1                     ; return failure
            sep   sret


          ; If an error occurs writing the file, give up.

writerr:    sep   scall                 ; display failure message
            dw    o_inmsg
            db    'ERROR: unable to write directory',13,10,0

            sep   scall                 ; attempt to close file anyway
            dw    o_close

            ldi   1                     ; return failure
            sep   sret

 
          ; File descriptor for directory

fildes:     dw    0,0                   ; offset
            dw    dta                   ; dta address
            dw    0                     ; eof length
            db    0                     ; flags
            dw    0,0                   ; directory sector
            dw    0                     ; director offset
            dw    0,0                   ; loaded sector


          ; I/O buffer for directory entry

dirprev:    db    0                     ; byte before

diraddr:    dw    0,0                   ; file offset
            dw    0                     ; eof length
dirflag:    db    0                     ; flags
            dw    0,0                   ; date and time
            db    0                     ; aux flags
dirname:    ds    19                    ; file name
dirlast:    db    0                     ; termating zero


          ; The following buffers are included in the executable size in the
          ; header so that memory space is checked for them, but they are not
          ; actually included in the executable.
          ;
          ; Note that the target name must be preceeded by a zero type for
          ; parsing the start, this is provided by the last byte of the
          ; directory entry, so be careful with rearranging these.

target:     ds    256                   ; copy of target path name
dta:        ds    512                   ; dta for file descriptor

end:        end   start                 ; end of static program space

