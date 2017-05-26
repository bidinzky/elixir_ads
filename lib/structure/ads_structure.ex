defmodule Ads.Structure do
    alias Ads.Structure.ObjToBinary
    alias Ads.Structure.BinaryToObj
    alias Ads.Structure.Size
    @moduledoc"""
        Ads Helper for Parsing JSON-Typ Definitions
    """
    def flatList([b] = arr) when is_list(arr) and length(arr) == 1, do: b
    def flatList(arr), do: arr

    def struct_to_bin(definition, data), do: ObjToBinary.deserialize(definition, data)
    def bin_to_struct(definition, data) when is_bitstring(definition) do
        {value, ""} = BinaryToObj.serialize(definition, data)
        value
    end
    def bin_to_struct(definition, data), do: BinaryToObj.serialize(definition, data)
    def sizeOf(definition), do: Size.size(definition)
end
