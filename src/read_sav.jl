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


using Logging

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

"""
    Define the different data types that can be found in an IDL save file
"""
DTYPE_DICT = Dict(1 => UInt8,
                2 => Int16,
                3 => Int32,
                4 => Float32,
                5 => Float64,
                6 => ComplexF64,
                7 => DataType,
                8 => DataType,
                9 => DataType,
                10 => DataType,
                11 => DataType,
                12 => UInt16,
                13 => UInt32,
                14 => Int64,
                15 => UInt64)


"""
    Define a dictionary to contain structure definitions.
    Will be filled by readStructDesc
"""
STRUCT_DICT = Dict()


abstract type IDLRecord end

struct Variable <: IDLRecord
    name::String
    data::Any
end

struct Timestamp <: IDLRecord
    date::String
    user::String
    host::String
end

struct Version <: IDLRecord
    format::Int32
    arch::String
    os::String
    release::String
end

struct Identification <: IDLRecord
    author::String
    title::String
    idCode::String
end

struct Notice <: IDLRecord
    notice::String
end

struct HeapHeader <: IDLRecord
    nValues::Int32
    indices::Array{Int32,1}
end

struct HeapData <: IDLRecord
    heapIndex::Int32
    data::Any
end

struct CommonBlock <: IDLRecord
    nVars::Int32
    name::String
    varNames::Array{String,1}
end

struct EndMarker <: IDLRecord
    finish::Bool
end

struct Pointer
    index::Int32
end



# -------------------------------- Descriptors -------------------------------- #
struct ArrayDesc 
    arrStart::Int32
    nBytes::Int32
    nElements::Int32
    nDims::Int32
    nMax::Int32
    dims::Vector{Int32}
end 

mutable struct TagDesc 
    name::String
    offset::UInt64
    typeCode::Int32
    array::Bool
    structure::Bool
    scalar::Bool
end

struct StructDesc
    name::String
    nTags::Int32
    nBytes::Int32
    preDef::Int32
    inherits::Int32
    isSuper::Int32
    tagTable::Vector{TagDesc}
    arrTable::Dict
    structTable::Dict
    className::Union{String,Nothing}
    nSupClasses::Union{Int32,Nothing}
    supClassNames::Union{Vector{String},Nothing}
    supClassTable::Union{Vector{StructDesc},Nothing}
end

struct TypeDesc 
    name::Union{Symbol, Nothing} # :ARRAY or :STRUCTURE
    typeCode::Int32
    varflags::Int32
    arrayDesc::Union{ArrayDesc, Nothing}
    structDesc::Union{StructDesc,Nothing}
end




"""
    Functions to read in Types
    Values come in chunks of 4 or 8 bytes
"""
function readByte(s::IOStream)
    var = read(s, 1)
    skip(s, 3)
    return var
end

function readLong(s::IOStream)
    return ntoh(read(s, Int32))
end

function readInt16(s::IOStream)
    skip(s, 2)
    return ntoh(read(s, Int16))
end

function readInt32(s::IOStream)
    return ntoh(read(s, Int32))
end

function readInt64(s::IOStream)
    return ntoh(read(s, Int64))
end

function readUInt16(s::IOStream)
    skip(s, 2)
    return ntoh(read(s, UInt16))
end

function readUInt32(s::IOStream)
    return ntoh(read(s, UInt32))
end

function readUInt64(s::IOStream)
    return ntoh(read(s, UInt64))
end

function readFloat32(s::IOStream)
    return ntoh(read(s, Float32))
end

function readFloat64(s::IOStream)
    return ntoh(read(s, Float64))
end


"""
    Align to the next 32-bit position in a file
"""
function align32(s::IOStream)
    pos = position(s)
    if pos % 4 != 0
        seek(s, pos + 4 - pos % 4)
    end
end


"""
    Reads a string
"""
function readString(s::IOStream)
    length = readLong(s)
    if length > 0
        chars = Vector{UInt8}()
        readbytes!(s, chars, length)
        align32(s)
        chars = String(chars)
    else 
        chars = ""
    end

    chars
end

function readStringData(s::IOStream)
    #= Reads a data string =#
    length = read(s, Int32)
    if length > 0
        length = read(s, Int32)
        stringData = Vector{UInt8}()
        readbytes!(s, stringData, length)
        stringData = String(stringData)
        align32(s)
    else 
        stringData = ""
    end

    stringData
end

"""
    Read in a variable with specified data type
"""
function readData(s::IOStream, typeCode)
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
        return Complex(real, imag)
    elseif typeCode == 7
        return readStringData(s)
    elseif typeCode == 8
        error("Should not be here")
    elseif typeCode == 9
        real = readFloat64(s)
        imag = readFloat64(s)
        return Complex(real, imag)
    elseif typeCode == 10
        return Pointer(readInt32(s))
    elseif typeCode == 11
        return Pointer(readInt32(s))
    elseif typeCode == 12
        return readUInt16(s)
    elseif typeCode == 13
        return readUInt32(s)
    elseif typeCode == 14
        return readInt64(s)
    elseif typeCode == 15 
        return readUInt64(s)
    else
        error("Unknown IDL type $(typeCode)")
    end
end

"""
    Read an array of type `typecode`, with the array descriptor given as
    `arrayDesc`
"""
function readArray(s::IOStream, typeCode, arrayDesc::ArrayDesc)
    if typeCode in [1, 3, 4, 5, 6, 9, 13, 14, 15]
        if typeCode == 1
            nbytes = readInt32(s)
            if nbytes != arrayDesc.nBytes
                @warn "Not able to verify number of bytes from header"
            end
        end
        # Read bytes as numpy array
        bytes = read(s, arrayDesc.nBytes)
        array = Vector(ntoh.(reinterpret(DTYPE_DICT[typeCode], bytes)))

    elseif typeCode in [2, 12]
        # These are 2 byte types, need to skip every two as they are not packed
        bytes = read(s, arrayDesc.nBytes * 2)
        array = Vector(ntoh.(reinterpret(DTYPE_DICT[typeCode], bytes)))[2:2:end]
 
    else
        array = []  # Read bytes into list
        for i in 1:(arrayDesc.nElements)
            dtype = typeCode
            data = readData(s, dtype)
            push!(array, data)
        end
    end

    # Reshape array if needed
    if arrayDesc.nDims > 1
        dims = [Int64(arrayDesc.dims[n]) for n in 1:arrayDesc.nDims]        
        array = reshape(array, dims...) # Fortran order
    end

    # Go to next alignment position
    align32(s)

    array
end


"""
    Read a structure, with the array and structure descriptors given as
`arrayDesc` and `structDesc` respectively.
    We use Julia Dict (of vectors) in place of numpy.recarray
"""
function readStructure(s::IOStream, arrayDesc::ArrayDesc, structDesc::StructDesc)
    nrows = arrayDesc.nElements
    columns = structDesc.tagTable

    #no need for type informations since we are using Julia Dicts.
    # might be non optimal

    # dtype = [] 
    # for col in columns
    #     cname_lower = lowercase(col.name)
    #     if col.structure || col.array
    #         push!(dtype,((cname_lower, col.name), "np_object"))
    #     else
    #         if col.typeCode in DTYPE_DICT
    #             push!(dtype,((cname_lower, col.name), DTYPE_DICT[col.typeCode]))
    #         else
    #             error("Variable type $(col.typeCode) not implemented")
    #         end
    #     end
    # end

    structure = Dict()

    for i in 1:nrows
        for col in columns
            dtype = col.typeCode
            if col.structure
                value = readStructure(s, structDesc.arrTable[col.name],
                                      structDesc.structTable[col.name])
            elseif col.array
                value = readArray(s, dtype, structDesc.arrTable[col.name])
            else
                value = readData(s, dtype)
            end
            row = get(structure, col.name, [])
            push!(row, value)
        end
    end

    # Reshape structure if needed
    if arrayDesc.nDims > 1
        error("Julia version does not implement structure with multi-dimentionnal arrays")
        # dims = arrayDesc.dims[:int(arrayDesc.nDims)]
        # dims.reverse()
        # structure = structure.reshape(dims)
    end
    
    structure
end


function readTagDesc(s::IOStream)
    offset = readLong(s)
    if offset == -1
        offset = readUInt64(s)
    end

    typeCode = readLong(s)
    tagflags = readLong(s)

    array = tagflags & 4 == 4
    structure = tagflags & 32 == 32
    scalar = typeCode in DTYPE_DICT
    TagDesc("", offset, typeCode, array, structure, scalar)
end

"""
    Function to read in an array descriptor
"""
function readArrayDesc(s::IOStream)
    arrStart = readLong(s)

    if arrStart == 8
        skip(s, 4)

        nBytes = readLong(s)
        nElements = readLong(s)
        nDims = readLong(s)

        skip(s, 8)

        nMax = readLong(s)
        dims = []
        for d in 1:nMax
            push!(dims, readLong(s))
        end 

    elseif arrStart == 18
        @warn "Using experimental 64-bit array read"

        skip(s, 8)

        nBytes = readUInt64(s)
        nElements = readUInt64(s)
        nDims = readLong(s)

        skip(s, 8)

        nMax = 8
        dims = []
        for d in 1:nMax
            v = readLong(s)
            if v != 0
                error("Expected a zero in ARRAY_DESC")
            end
            push!(dims, readLong(s))
        end
    else
        error("Unknown ARRSTART: $(arrStart)")
    end

    ArrayDesc(arrStart, nBytes, nElements, nDims, nMax, dims)
end

"""
    Function to read in a structure descriptor (recursive)
"""
function readStructDesc(s::IOStream)
    structstart = readLong(s)

    if structstart != 9
        error("STRUCTSTART should be 9")
    end 

    name = readString(s)
    predef = readLong(s)
    nTags = readLong(s)
    nBytes = readLong(s)

    preDef = predef & 1
    inherits = predef & 2
    isSuper = predef & 4

    if !preDef
        tagTable = TagDesc[]
        for t in 1:nTags
            push!(tagTable, readTagDesc(s))
        end 

        for tag in tagTable
            tag.name = readString(s)
        end 

        arrTable = Dict()
        for tag in tagTable
            if tag.array
                arrTable[tag.name] = readArrayDesc(s)
            end 
        end 

        structTable = Dict()
        for tag in tagTable
            if tag.structure 
                structTable[tag.name] = readStructDesc(s)
            end
        end 

        if inherits && isSuper
            className = readString(s)
            nSupClasses = readLong(s)
            supClassNames = []
            for s in 1:nSupClasses
                push!(supClassNames, readString(s))
            end 
            supClassTable = []
            for s in 1:nSupClasses
                push!(supClassTable, readStructDesc(s))
            end
        else
            className = nothing
            nSupClasses = nothing
            supClassNames = nothing
            supClassTable = nothing
        end 
        structdesc = StructDesc(name, nTags, nBytes, preDef, inherits, isSuper, tagTable,
                                arrTable, structTable, className, nSupClasses, supClassNames, supClassTable)
        
        STRUCT_DICT[name] = structdesc

    else
        if !(name in STRUCT_DICT)
            error("PREDEF=1 but can't find definition")
        end 
        structdesc = STRUCT_DICT[name]
    end
    structdesc
end




function readTypeDesc(s::IOStream)
    typeCode = readLong(s)
    varflags = readLong(s)
    if varflags & 2 == 2
        error("System variables not implemented")
    end

    array = (varflags & 4) == 4
    structure = (varflags & 32) == 32
    
    if structure
        name = :STRUCTURE
        arrayDesc = readArrayDesc(s)
        structDesc = readStructDesc(s)
    elseif array
        name = :ARRAY
        arrayDesc = readArrayDesc(s)
        structDesc = nothing
    else 
        name = nothing
        arrayDesc = nothing
        structDesc = nothing
    end

    TypeDesc(name, typeCode, varflags, arrayDesc, structDesc)
end

"""
Function to read in a full record
"""
function readRecord(s::IOStream)
    
    recType =  readLong(s)
    nextRec =  readUInt32(s)
    nextRec += readUInt32(s) * 2^32
    skip(s, 4)

    haskey(RECTYPE_DICT, recType) || error("Unknown RECTYPE: $(recType)")

    recType = RECTYPE_DICT[recType]

    if recType in ["VARIABLE","HEAP_DATA"]
        if recType == "VARIABLE"
            varName = readString(s)
        else
            heapIndex = readLong(s)
            skip(s, 4)
        end
        
        rtd = readTypeDesc(s)

        if rtd.typeCode == 0
            if nextRec == position(s)
                data = nothing   # Indicates NULL value
            else
                error("Unexpected type code: 0")
            end
        else
            varStart = readLong(s)
            varStart == 7 || error("VARSTART is not 7")

            if rtd.name == :STRUCTURE
                data = readStructure(s, rtd.arrayDesc, rtd.structDesc)
            elseif rtd.name == :ARRAY
                data = readArray(s, rtd.typeCode, rtd.arrayDesc)
            else 
                dType = rtd.typeCode
                data = readData(s, dType)
            end
        end

        if recType == "VARIABLE"
            record = Variable(varName, data)
        else
            record = HeapData(heapIndex, data)
        end

    elseif recType == "TIMESTAMP"
        skip(s, 4 * 256)
        date = readString(s)
        user = readString(s)
        host = readString(s)
        record = Timestamp(date, user, host)
    elseif recType == "VERSION"
        format = readLong(s)
        arch = readString(s)
        os = readString(s)
        release = readString(s)
        record = Version(format, arch, os, release)
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
        for i = 1:nValues
            index = readLong(s)
            push!(indices, index)
        end
        record = HeapHeader(nValues, indices)
    elseif recType == "COMMONBLOCK"
        nVars = readLong(s)
        name = readString(s)
        varNames = String[]
        for i = 1:nVars
            varName = readString(s)
            push!(varNames, varName)
        end
        record = CommonBlock(nVars, name, varNames)
    elseif recType == "END_MARKER"
        record = EndMarker(true)
    elseif recType == "SYSTEM_VARIABLE"
        @warn "Skipping SYSTEM_VARIABLE record"
    else
        error("Record Type is not implemented")
    end

    seek(s, nextRec)
    return record
end

function replaceHeap(variable, heap)
    error("Julia version does not implement Heap support.")
end


"""
    readsav(fname; verbose = false)

    Read an IDL .sav file. If verbose, print out information about the .sav file.
"""
function readsav(fname::String; verbose = false)


    # Open the IDL file
    f = open(fname, "r")

    # Read the signature
    sig = Vector{UInt8}()
    readbytes!(f, sig, 2)
    sig == b"SR" || error("Invald Signature: $(String(sig))")

    recfmt = Vector{UInt8}()
    readbytes!(f, recfmt, 2)

    if recfmt == b"\x00\x04"
        Nothing()
    elseif recfmt == b"\x00\x06"
        error("Cannot handle compressed files right now")
    else
        error("Invalid Record Format: $(string(recfmt))")
    end

    records = IDLRecord[]
    while true
        r = readRecord(f)
        push!(records, r)
        typeof(r) == EndMarker && break
    end
    close(f)

    variables = Dict()
    meta = Dict()
    for r in records
        if typeof(r) == Variable
            variables[r.name] = r.data
        elseif typeof(r) in [Timestamp, Version, Identification]
            meta[typeof(r)] = r
        end
    end 

    if verbose
        # Print out timestamp info about the file
        if haskey(meta, Timestamp)
            record = meta[Timestamp]
            println("-"^50)
            println("Date: $(record.date)")
            println("User: $(record.user)")
            println("Host: $(record.host)")
        end

        # Print out version info about the file
        if haskey(meta, Version)
            record = meta[Version]
            println("-"^50)
            println("Format: $(record.format)")
            println("Architecture: $(record.arch)")
            println("Operating System: $(record.os)")
            println("IDL Version: $(record.release)")
        end

        # Print out identification info about the file
        if haskey(meta, Identification)
            record = meta[Identification]
            println("-"^50)
            println("Author: $(record.author)")
            println("Title: $(record.title)")
            println("ID Code: $(record.idcode)")
        end
        println("-"^50)
    end 

    variables
end