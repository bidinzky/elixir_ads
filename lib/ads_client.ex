defmodule Ads.Client do
  use GenServer
  alias Ads.Structure
  alias Ads.Structure.Size
  alias Ads.Client.Handler

  @moduledoc """
    Ads Client
  """
  def start_link ip, port, amsNetId, amsPort, sourceNetId do
      GenServer.start_link(
        __MODULE__,
        %{
            socket: nil,
            packets: %{},
            queue: :queue.new(),
            ip: ip,
            port: port,
            amsNetId: amsNetId,
            amsPort: amsPort,
            sourceNetId: sourceNetId,
            key: nil
        }
    )
  end

  def init(state) do
      opts = [:binary, active: true, keepalive: true, nodelay: true, buffer: 1_000_000]
      case :gen_tcp.connect(state.ip, state.port, opts) do
        {:ok, socket} ->
            {
                :ok,
                %{
                    state | socket: socket,
                    key: :ets.new(
                        :AdsClient,
                        []
                    )
                }
            }
        _ -> {:error, :timeout}
      end
  end

  def read(pid, handle, type) when (is_bitstring(type) or is_list(type)) do
    t = Size.size(type)
    with  {:ok, bin_data} <- read(pid, handle, t),
        data <- Structure.bin_to_struct(type, bin_data)
    do
        {:ok, data}
    else
        error -> {:error, error}
    end
  end

  def read(pid, varName, length) when is_bitstring(varName) and is_number(length)  do
      handle = pid
        |> GenServer.call({:getSymHandle, varName})
        |> Handler.parseGetHandleByName
      case handle do
          {:ok, h} ->
              read pid, h, length
          {:error, _err} ->
              {:error, :no_handle}
      end
  end

  def read(pid, handle, length) when is_number(handle) and is_number(length) do
    pid
        |> GenServer.call({:read, handle, length})
        |> Handler.parseRead
  end



  def write(pid, handle, data, definition) when is_list(definition) or is_bitstring(definition) do
      binary_data = Structure.struct_to_bin(definition, data)
      write(pid, handle, binary_data)
  end

  def write(pid, varName, data) when is_bitstring(varName) and is_bitstring(data) do
      handle = pid
            |> GenServer.call({:getSymHandle, varName})
            |> Handler.parseGetHandleByName
      case handle do
          {:ok, h} ->
              write pid, h, data
          {:error, _err} ->
              {:error, :no_handle}
      end
  end

  def write(pid, handle, data) when is_number(handle) and is_bitstring(data) do
      pid
        |> GenServer.call({:write, handle, data})
        |> Handler.parseWrite
  end




  def handle_call({:getSymHandle, varName}, from, state) do
      id = Handler.timestamp
      p = varName
            |> Handler.getHandleByName
            |> Handler.addAmsHeader(
                state.amsNetId,
                state.amsPort,
                state.sourceNetId,
                32_905,
                id
            )
            |> Handler.addAmsTcpHeader()
      :ok = :gen_tcp.send(state.socket, p)
      state = %{state |  packets: Map.put(state.packets, id, from)}
      {:noreply, state}
  end

  def handle_call({:read, handle, length}, from, state) do
      id = Handler.timestamp
      p =   handle
            |> Handler.read(length)
            |> Handler.addAmsHeader(
                state.amsNetId,
                state.amsPort,
                state.sourceNetId,
                32_905,
                id
            )
            |> Handler.addAmsTcpHeader()
      :ok = :gen_tcp.send(state.socket, p)
      state = %{state |  packets: Map.put(state.packets, id, from)}
      {:noreply, state}
  end

  def handle_call({:write, handle, data}, from, state) do
      id = Handler.timestamp
      p = handle
            |> Handler.write(data)
            |> Handler.addAmsHeader(
                state.amsNetId,
                state.amsPort,
                state.sourceNetId,
                32_905,
                id
            )
            |> Handler.addAmsTcpHeader()
      :ok = :gen_tcp.send(state.socket, p)
      state = %{state |  packets: Map.put(state.packets, id, from)}
      {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
      init(state)
      {:noreply, state}
  end

  def handle_info({:tcp, _, msg}, state) do
    id = Handler.extractId(msg)
    q = Map.get(state.packets, id)
    if q != nil do
        GenServer.reply(q, msg)
        {:noreply, %{state | packets: Map.delete(state.packets, id)}}
    else
        {:noreply, state}
    end
  end
end

