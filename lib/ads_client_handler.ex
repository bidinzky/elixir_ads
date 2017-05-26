defmodule Ads.Client.Handler do
    @moduledoc"""
        Binary Protokoll implementation of ADS
    """
    def timestamp do
        {_, sec, ms} = :os.timestamp
        sec * 1000 + ms
    end
    
    # Header

    def addAmsTcpHeader p do
        <<0, 0, (byte_size p)::little-size(32)>> <> p
    end
    
    def addAmsHeader %{data: data, cId: cId}, amsNetIdTarget, amsPortTarget, amsNetIdSource, amsPortSource, id  do
        target_netid = :binary.list_to_bin amsNetIdTarget
        source_netid = :binary.list_to_bin amsNetIdSource
        target_netid <> <<
                amsPortTarget :: little-size(16)
            >> <> source_netid <> <<
                amsPortSource :: little-size(16),
                cId :: little-size(16),
                4 :: little-size(16),
                (byte_size data) :: little-size(32),
                0 :: little-size(32),
                id :: little-size(32)
            >> <> data
    end

    def remAmsTcpHeader data do
        << _::little-size(48), r::binary>> = data
        r
    end

    def remAmsHeader data do
        << _ :: size(192), error:: little-size(32), _::size(32), packet::binary>> = data
        if error != 0 do
            {:error}
        else
            {:ok, packet}
        end
    end

    def extractId data do
        <<_:: size(272), id::little-size(32), _::binary>> = data
        id
    end

    def extractCommandId data do
        <<_ :: size(176), command_id::little-size(16), _::binary>> = data
        command_id
    end

    def getHandleByName(varName) do
        readWrite 0x0000F003, 0x0, 4, varName
    end

    def parseGetHandleByName(data) do
        packet = data
            |> remAmsTcpHeader
            |> remAmsHeader

        with    {:ok, p} <- packet,
                <<e::little-size(32), _::little-size(32), h::little-size(32)>> <- p,
                :ok <- handleErrorCode(e)
        do
            {:ok, h}
        else
            err -> {:error, err}
        end
    end

    def read(handle, length) do
        read 0xF005, handle, length
    end

    def write(handle, data) do
        write 0xF005, handle, data
    end

    ## Low-Level

    # Read
    defp read indexGroup, indexOffset, length do
        %{data: <<indexGroup::little-size(32), indexOffset :: little-size(32), length :: little-size(32)>>, cId: 2}
    end

    def parseRead data do
        packet = data
            |> remAmsTcpHeader
            |> remAmsHeader

        with    {:ok, p} <- packet,
                <<e::little-size(32), _::little-size(32), h::binary>> <- p,
                :ok <- handleErrorCode(e)
        do
            {:ok, h}
        else
            error -> {:error, error}
        end
    end

    # Write
    defp write indexGroup, indexOffset, data do
        b = data#:binary.list_to_bin data
        %{data: <<indexGroup::little-size(32), indexOffset::little-size(32), (byte_size b)::little-size(32)>> <> b, cId: 3}
    end

    def parseWrite data do
        data
            |> remAmsTcpHeader
            |> remAmsHeader
            |> handleError
    end

    defp handleErrorCode(0), do: :ok
    defp handleErrorCode(_), do: :error

    defp handleError(packet) do
        with    {:ok, p} <- packet,
                <<e::little-size(32)>> <- p,
                :ok <- handleErrorCode(e)
        do
            :ok
        else
            error -> {:error, error}
        end
    end

    # ReadWrite (for getHandle)
    defp readWrite(indexGroup, indexOffset, rLen, data) when not is_binary(data) do
        readWrite(indexGroup, indexOffset, rLen, :binary.list_to_bin(data))
    end
    defp readWrite indexGroup, indexOffset, rLen, data do
        %{data: <<indexGroup :: little-size(32), indexOffset :: little-size(32), rLen :: little-size(32), (byte_size data) :: little-size(32)>> <> data, cId: 9}
    end
end
