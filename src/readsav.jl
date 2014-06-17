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

abstract IDLRecord

type Variable <: IDLRecord
    name::String
    data::Any
end

type Timestamp <: IDLRecord
    date::String
    user::String
    host::String
end

type Version <: IDLRecord
    format::Int32
    arch::String
    os::String
    release::String
end

type Identification <: IDLRecord
    author::String
    title::String
    idCode::String
end

type Notice <: IDLRecord
    notice::String
end

type HeapHeader <: IDLRecord
    nValues::Int32
    indices::Array{Int32,1}
end

type HeapData <: IDLRecord
    heapIndex::Int32
    data::Any
end

type CommonBlock <: IDLRecord
    nVars::Int32
    name::String
    varNames::Array{String,1}
end

type EndMarker <: IDLRecord
    finish::Bool
end

type Pointer
    index::Int32
end

# Functions to read in Types
# Values come in chunks of 4 or 8 bytes
function readByte(s::IOStream)
    var=readbytes(s,1)
    skip(s,3)
    return var
end

function readLong(s::IOStream)
    return htonread(s,Int32))
end

function readInt16(s::IOStream)
    skip(s,2)
    return hton(read(s,Int16))
end

function readInt32(s::IOStream)
    return hton(read(s,Int32))
end

function readInt64(s::IOStream)
    return hton(read(s,Int64))
end

function readUint16(s::IOStream)
    skip(s,2)
    return hton(read(s,Uint16))
end

function readUint32(s::IOStream)
    return hton(read(s,Uint32))
end

function readUint64(s::IOStream)
    return hton(read(s,Uint64))
end

function readFloat32(s::IOStream)
    return hton(read(s,Float32))
end

function readFloat64(s::IOStream)
    return hton(read(s,Float64))
end

function align32(s::IOStream)
   #= Align to the next 32-bit position in a file =#

   pos=position(s)
   if pos % 4 != 0
     seek(s, pos + 4 - pos % 4)
   end
end

function readString(s::IOStream)
    #= Reads a string =#
    length=read(s,Int32)
    if length > 0
        chars = readbytes(s,length)
        align32(s)
        chars = bytestring(chars)
    else 
        chars=""
    end

    return chars
end

function readStringData(s::IOStream)
    #= Reads a data string =#
    length = read(s,Int32)
    if length > 0
        length = read(s,Int32)
        stringData = readbytes(s,length)
        stringData = bytestring(stringData)
        align32(s)
    else 
        stringData=""
    end

    return stringData
end

function readData(s::IOStream,typeCode)
    # Read in a variable with specified data type
    if typeCode == 1
        if readInt32(s) != 1
            error("Error occured while reading byte variable")
        end
        return readByte(s)
    elseif typeCode == 2
        return readInt16(s)
    elseif typeCode == 3
        return readInt32(s)
    elseif typeCode == 4
        return readFloat32(s)
    elseif typeCode == 5
        return readFloat64(s)
    elseif typeCode == 6
        real = readFloat32(s)
        imag = readFloat32(s)
        return Complex(real,imag)
    elseif typeCode == 7
        return readStringData(s)
    elseif typeCode == 8
        error("Should not be here")
    elseif typeCode == 9
        real = readFloat64(s)
        imag = readFloat64(s)
        return Complex(real,imag)
    elseif typeCode == 10
        return Pointer(readInt32(s))
    elseif typeCode == 11
        return Pointer(readInt32(s))
    elseif typeCode == 12
        return readUint16(s)
    elseif typeCode == 13
        return readUint32(s)
    elseif typeCode == 14
        return readInt64(s)
    elseif typeCode == 15 
        return readUint64(s)
    else
        error("Unknown IDL type $(typeCode)")
    end
end

function readArray(s::IOStream,typeCode,arrayDesc)
end

function readStructure(s::IOStream,arrayDesc,structDesc)
end

function readTagDesc(s::IOStream)
end

function readArrayDesc(s::IOStream)
end

function readStructDesc(s::IOStream)
end

function readTypeDesc(s::IOStream)
end

function readRecord(s::IOStream)
    # Function to read in a full record
    recType =  readLong(s)
    nextRec =  readUint32(s)
    nextRec += readUint32(s) * 2^32
    skip(s,4)

    haskey(RECTYPE_DICT,recType) || error("Unknown RECTYPE: $(recType)")

    recType=RECTYPE_DICT[recType]

    if recType in ["VARIABLE","HEAP_DATA"]
        if recType == "VARIABLE"
            varName = readString(s)
        else
            heapIndex = readLong(s)
            skip(s,4)
        end
        
        rtd = readTypeDesc(s)
        varStart = readLong(s)
        varStart == 7 || error("VARSTART is not 7")

        if rtd.name == "STRUCTURE"
            data = readStructure(s,rtd.arrayDesc,rtd.structDesc)
        elseif rtd.name == "ARRAY"
            data = readArray(s,rtd.typeCode,rtd.arrayDesc)
        else 
            dType = rtd.typeCode
            data = readData(s,dType)
        end

        if recType == "VARIABLE"
            record = Variable(varName,data)
        else
            record = HeapData(heapIndex,data)
        end

    elseif recType == "TIMESTAMP"
        skip(s,4*256)
        date = readString(s)
        user = readString(s)
        host = readString(s)
        record = Timestamp(date,user,host)
    elseif recType == "VERSION"
        format = readLong(s)
        arch = readString(s)
        os = readString(s)
        release = readString(s)
        record = Version(format,arch,os,release)
    elseif recType == "IDENTIFICATION"
        author = readString(s)
        title = readString(s)
        idCode = readString(s)
    elseif recType == "NOTICE"
        notice = readString(s)
        record = Notice(notice)
    elseif recType == "HEAP_HEADER"
        nValues = readLong(s)
        indices = Int32[]
        for i=1:nValues
            index=readLong(s)
            push!(indices,index)
        end
        record = HeapHeader(nValues,indices)
    elseif recType == "COMMONBLOCK"
        nVars = readLong(s)
        name = readString(s)
        varNames = String[]
        for i=1:nVars
            varName=readString(s)
            push!(varNames,varName)
        end
        record = CommonBlock(nVars,name,varNames)
    elseif recType == "END_MARKER"
        record = EndMarker(true)
    elseif recType == "SYSTEM_VARIABLE"
        warn("Skipping SYSTEM_VARIABLE record")
    else
        error("Record Type is not implemented")
    end

    seek(s,nextRec)
    return record
end

function replaceHeap(variable,heap)
end

function readsav(fname::String; verbose=false)
    #= 
    Read an IDL .sav file
    
    Parameters
    ----------
    fname : String
        Name of the IDL save file
    verbose : bool, optional
        Print out information about the .sav file
    =#

    # Open the IDL file
    f = open(fname,"r")

    # Read the signature
    sig = readbytes(f,2)
    sig == b"SR" || error("Invald Signature: $(bytestring(sig))")

    recfmt = readbytes(f,2)

    if recfmt == b"\x00\x04"
        Nothing()
    elseif recfmt == b"\x00\x06"
        error("Cannot handle compressed files right now")
    else
        error("Invalid Record Format: $(string(recfmt))")
    end

    records=IDLRecord[]
    while true
        r=readRecord(f)
        push!(records,r)
        typeof(r) == EndMarker && break
    end

    close(f)
end

