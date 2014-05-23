# Copyright (c) 2014 Luke Stagner

# Many thanks to Craig Markwardt for publishing the Unofficial Format
# Specification for IDL .sav files, without which this Python module would not
# exist (http://cow.physics.wisc.edu/~craigm/idl/savefmt).

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Define the different data types that can be found in an IDL .sav file
DTYPE_DICT = Dict()
DTYPE_DICT[1] = '>u1'
DTYPE_DICT[2] = '>i2'
DTYPE_DICT[3] = '>i4'
DTYPE_DICT[4] = '>f4'
DTYPE_DICT[5] = '>f8'
DTYPE_DICT[6] = '>c8'
DTYPE_DICT[7] = '|O'
DTYPE_DICT[8] = '|O'
DTYPE_DICT[9] = '>c16'
DTYPE_DICT[10] = '|O'
DTYPE_DICT[11] = '|O'
DTYPE_DICT[12] = '>u2'
DTYPE_DICT[13] = '>u4'
DTYPE_DICT[14] = '>i8'
DTYPE_DICT[15] = '>u8'

# Define the different record types that can be found in an IDL save file
RECTYPE_DICT = Dict()
RECTYPE_DICT[0] = "START_MARKER"
RECTYPE_DICT[1] = "COMMON_VARIABLE"
RECTYPE_DICT[2] = "VARIABLE"
RECTYPE_DICT[3] = "SYSTEM_VARIABLE"
RECTYPE_DICT[6] = "END_MARKER"
RECTYPE_DICT[10] = "TIMESTAMP"
RECTYPE_DICT[12] = "COMPILED"
RECTYPE_DICT[13] = "IDENTIFICATION"
RECTYPE_DICT[14] = "VERSION"
RECTYPE_DICT[15] = "HEAP_HEADER"
RECTYPE_DICT[16] = "HEAP_DATA"
RECTYPE_DICT[17] = "PROMOTE64"
RECTYPE_DICT[19] = "NOTICE"

# Define a dictionary to contain structure definitions
STRUCT_DICT = Dict()

function _align_32(s::IOStream)
    #= Align to the next 32-bit position in a file =#

    pos=position(s)
    if pos % 4 != 0
      seek(s, pos + 4 - pos % 4)
    end
end

type IDLPointer
    #= Type used to define pointers =#
    index
end

function _read_string(s::IOStream)
    #= Reads a string =#
    length=read(s,Int32)
    if length > 0
        chars = readbytes(s,length)
        _align_32(s)
        chars = bytestring(chars)
    else 
        chars=""
    end

    return chars
end

function _read_string_data(s::IOStream)
    #= Reads a data string =#
    length = read(s,Int32)
    if length > 0
        length = read(s,Int32)
        string_data = readbytes(s,length)
        string_data = bytestring(string_data)
        _align_32(s)
    else 
        string_data=""
    end

    return string_data
end


