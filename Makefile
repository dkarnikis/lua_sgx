######## SGX SDK Settings ########

SGX_SDK ?= /opt/intel/sgxsdk
SGX_ARCH ?= x64

SGX_MODE?=HW
SGX_PRERELEASE?=1
#SGX_DEBUG ?=1
ifeq ($(shell getconf LONG_BIT), 32)
	SGX_ARCH := x86
else ifeq ($(findstring -m32, $(CXXFLAGS)), -m32)
	SGX_ARCH := x86
endif

ifeq ($(SGX_ARCH), x86)
	SGX_COMMON_CFLAGS := -m32 -pie -fPIE
	SGX_LIBRARY_PATH := $(SGX_SDK)/lib
	SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/sgx_sign
	SGX_EDGER8R := $(SGX_SDK)/bin/x86/sgx_edger8r
else
	SGX_COMMON_CFLAGS := -m64 -pie -fPIE
	SGX_LIBRARY_PATH := $(SGX_SDK)/lib64
	SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/x64/sgx_sign
	SGX_EDGER8R := $(SGX_SDK)/bin/x64/sgx_edger8r
endif

ifeq ($(SGX_DEBUG), 1)
ifeq ($(SGX_PRERELEASE), 1)
$(error Cannot set SGX_DEBUG and SGX_PRERELEASE at the same time!!)
endif
endif

ifeq ($(SGX_DEBUG), 1)
        SGX_COMMON_CFLAGS += 
else
        SGX_COMMON_CFLAGS += 
endif

LUA_FLAGS = -Ofast -Wall -Wno-misleading-indentation -Wno-sign-compare -Wno-stringop-overflow #-g -DDEBUG
SGX_COMMON_FLAGS += -Wall -Wextra -Winit-self -Wpointer-arith -Wreturn-type \
                    -Waddress -Wsequence-point -Wformat-security \
                    -Wfloat-equal -Wundef -Wshadow \
                    -Wcast-align -Wcast-qual -Wconversion -Wredundant-decls $(LUA_FLAGS)
SGX_COMMON_CFLAGS := $(SGX_COMMON_FLAGS)  $(LUA_FLAGS)
SGX_COMMON_CXXFLAGS := $(SGX_COMMON_FLAGS) -Wnon-virtual-dtor -std=c++11 $(LUA_FLAGS)

APP_C_Flags += $(LUA_FLAGS)
SGX_COMMON_CFLAGS +=  $(LUA_FLAGS)
######## App Settings ########

ifneq ($(SGX_MODE), HW)
	Urts_Library_Name := sgx_urts_sim
else
	Urts_Library_Name := sgx_urts
endif

App_Cpp_Files := $(wildcard App/*.cpp) 
App_Include_Paths := -IInclude -IApp -I$(SGX_SDK)/include

App_C_Flags := $(SGX_COMMON_CFLAGS) -pie -fPIE -fPIC  -Wno-attributes $(App_Include_Paths)  $(LUA_FLAGS)

# Three configuration modes - Debug, prerelease, release
#   Debug - Macro DEBUG enabled.
#   Prerelease - Macro NDEBUG and EDEBUG enabled.
#   Release - Macro NDEBUG enabled.



App_Cpp_Flags := $(App_C_Flags) -std=c++11 -pie -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -pthread -Wall -fpermissive $(LUA_FLAGS)
App_Link_Flags := $(SGX_COMMON_CFLAGS) -L$(SGX_LIBRARY_PATH) -l$(Urts_Library_Name) -pie -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -pthread $(LUA_FLAGS) -L./ -ldlua

ifneq ($(SGX_MODE), HW)
	App_Link_Flags += -lsgx_uae_service_sim 
else
	App_Link_Flags += -lsgx_uae_service
endif

App_Cpp_Objects := $(App_Cpp_Files:.cpp=.o)

App_Name := lua_vm

######## Enclave Settings ########

ifneq ($(SGX_MODE), HW)
	Trts_Library_Name := sgx_trts_sim
	Service_Library_Name := sgx_tservice_sim
else
	Trts_Library_Name := sgx_trts
	Service_Library_Name := sgx_tservice
endif
Crypto_Library_Name := sgx_tcrypto

Enclave_Cpp_Files := $(wildcard Enclave/*.cpp)  $(wildcard Enclave/dh/*.cpp)

Enclave_Include_Paths := -IInclude -IEnclave -I$(SGX_SDK)/include -I$(SGX_SDK)/include/tlibc -I$(SGX_SDK)/include/libcxx

Enclave_C_Flags := $(Enclave_Include_Paths) -nostdinc -fvisibility=hidden -fpie -ffunction-sections -fdata-sections $(LUA_FLAGS)


Enclave_Cpp_Flags := $(Enclave_C_Flags) -nostdinc++ -fpermissive -std=gnu++11 $(LUA_FLAGS)# -g -DDEBUG -std=c++11 


Enclave_Link_Flags := -Wl,--no-undefined -nostdlib -nodefaultlibs -nostartfiles -L$(SGX_LIBRARY_PATH) \
        -Wl,--whole-archive -l$(Trts_Library_Name) -Wl,--no-whole-archive \
        -Wl,--start-group -lsgx_tstdc -lsgx_tcxx -l$(Crypto_Library_Name) -l$(Service_Library_Name) -Wl,--end-group \
        -Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
        -Wl,-pie,-eenclave_entry -Wl,--export-dynamic  \
        -Wl,--defsym,__ImageBase=0 -Wl,--gc-sections   \
        -Wl,--version-script=Enclave/Enclave.lds       \
    	-Wl,--allow-multiple-definition 

Enclave_Cpp_Objects := $(Enclave_Cpp_Files:.cpp=.o) 

Enclave_Name := enclave.so
Signed_Enclave_Name := enclave.signed.so
Enclave_Config_File := Enclave/Enclave.config.xml

ifeq ($(SGX_MODE), HW)
ifneq ($(SGX_DEBUG), 1)
ifneq ($(SGX_PRERELEASE), 1)
Build_Mode = HW_RELEASE
endif
endif
endif


.PHONY: all run

ifeq ($(Build_Mode), HW_RELEASE)
all: $(App_Name) $(Enclave_Name)
	@echo "The project has been built in release hardware mode."
	@echo "Please sign the $(Enclave_Name) first with your signing key before you run the $(App_Name) to launch and access the enclave."
	@echo "To sign the enclave use the command:"
	@echo "   $(SGX_ENCLAVE_SIGNER) sign -key <your key> -enclave $(Enclave_Name) -out <$(Signed_Enclave_Name)> -config $(Enclave_Config_File)"
	@echo "You can also sign the enclave using an external signing tool. See User's Guide for more details."
	@echo "To build the project in simulation mode set SGX_MODE=SIM. To build the project in prerelease mode set SGX_PRERELEASE=1 and SGX_MODE=HW."
else
all: $(App_Name) $(Signed_Enclave_Name)
endif

run: all
ifneq ($(Build_Mode), HW_RELEASE)
	@$(CURDIR)/$(App_Name)
	@echo "RUN  =>  $(App_Name) [$(SGX_MODE)|$(SGX_ARCH), OK]"
endif

######## App Objects ########

App/Enclave_u.c: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd App && $(SGX_EDGER8R) --untrusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

App/Enclave_u.o: App/Enclave_u.c
	@$(CXX) $(App_C_Flags) -c $< -o $@ 
	@echo "CXX   <=  $<"

App/%.o: App/%.cpp 
	@$(CXX) $(App_Cpp_Flags) -c $< -o $@  
	@echo "CXX <=  $<"

$(App_Name): App/Enclave_u.o $(App_Cpp_Objects)
	@$(CXX) $^ $(App_Link_Flags) -o $@  
	@echo "LINK ->=>  $(App_Link_Flags)"


######## Enclave Objects ########

Enclave/Enclave_t.c: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd Enclave && $(SGX_EDGER8R) --trusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

Enclave/Enclave_t.o: Enclave/Enclave_t.c
	@$(CC) $(Enclave_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

	
Enclave/%.o:  Enclave/%.cpp 
	
	@$(CXX)  $(Enclave_Cpp_Flags) -c $< -o $@ 
	@echo "CXX  <=  $<"
#	@$(CXX) $(Enclave_Cpp_Flags)

$(Enclave_Name): Enclave/Enclave_t.o $(Enclave_Cpp_Objects)
	@$(CXX) $^ -o $@ $(Enclave_Link_Flags)
	@echo "LINK =>  $@"

$(Signed_Enclave_Name): $(Enclave_Name)
	@$(SGX_ENCLAVE_SIGNER) sign -key Enclave/Enclave_private.pem -enclave $(Enclave_Name) -out $@ -config $(Enclave_Config_File)
	@echo "SIGN =>  $@"

.PHONY: clean

clean:
	@rm -f $(App_Name) $(Enclave_Name) $(Signed_Enclave_Name) $(App_Cpp_Objects) App/Enclave_u.* $(Enclave_Cpp_Objects) Enclave/Enclave_t.*
