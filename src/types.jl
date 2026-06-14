const MxArray = Ptr{Cvoid}

# mxClassID constants (matches MATLAB enum order)
const mxUNKNOWN_CLASS = Cint(0)
const mxCELL_CLASS = Cint(1)
const mxSTRUCT_CLASS = Cint(2)
const mxLOGICAL_CLASS = Cint(3)
const mxCHAR_CLASS = Cint(4)
const mxVOID_CLASS = Cint(5)
const mxDOUBLE_CLASS = Cint(6)
const mxSINGLE_CLASS = Cint(7)
const mxINT8_CLASS = Cint(8)
const mxUINT8_CLASS = Cint(9)
const mxINT16_CLASS = Cint(10)
const mxUINT16_CLASS = Cint(11)
const mxINT32_CLASS = Cint(12)
const mxUINT32_CLASS = Cint(13)
const mxINT64_CLASS = Cint(14)
const mxUINT64_CLASS = Cint(15)
const mxFUNCTION_CLASS = Cint(16)
const mxOPAQUE_CLASS = Cint(17)
const mxOBJECT_CLASS = Cint(18)

# Complexity flags
const mxREAL = Cint(0)
const mxCOMPLEX = Cint(1)

# mxNumericType (used in mxCreateNumericArray, interleaved complex API)
const mxDOUBLE_ID = Cint(0)
const mxSINGLE_ID = Cint(1)
const mxINT8_ID = Cint(2)
const mxUINT8_ID = Cint(3)
const mxINT16_ID = Cint(4)
const mxUINT16_ID = Cint(5)
const mxINT32_ID = Cint(6)
const mxUINT32_ID = Cint(7)
const mxINT64_ID = Cint(8)
const mxUINT64_ID = Cint(9)

function mex_ext()::String
    if Sys.islinux()
        if Sys.ARCH === :x86_64
            return "mexa64"
        elseif Sys.ARCH === :aarch64
            return "mexal64"
        end
    elseif Sys.isapple()
        if Sys.ARCH === :aarch64
            return "mexmaca64"
        else
            return "mexmaci64"
        end
    elseif Sys.iswindows()
        return "mexw64"
    end
    error("Unsupported platform: $(Sys.KERNEL) $(Sys.ARCH)")
end
