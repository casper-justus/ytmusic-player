package com.ytmusic.player.ui.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.ytmusic.player.R
import com.ytmusic.player.YTMusicApp
import com.ytmusic.player.ui.adapters.LibraryAdapter
import kotlinx.coroutines.launch

class LibraryFragment : Fragment() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: LibraryAdapter
    private lateinit var loadingView: View
    private lateinit var emptyView: View
    private lateinit var downloadsSection: View

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_library, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        recyclerView = view.findViewById(R.id.library_recycler)
        loadingView = view.findViewById(R.id.library_loading)
        emptyView = view.findViewById(R.id.library_empty)
        downloadsSection = view.findViewById(R.id.library_downloads)

        adapter = LibraryAdapter(requireContext())
        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = adapter

        loadLibrary()
    }

    private fun loadLibrary() {
        loadingView.visibility = View.VISIBLE

        lifecycleScope.launch {
            val repo = YTMusicApp.instance.musicRepository
            repo.getLibraryPlaylists().fold(
                onSuccess = { items ->
                    loadingView.visibility = View.GONE
                    if (items.isEmpty()) {
                        emptyView.visibility = View.VISIBLE
                    } else {
                        adapter.submitList(items)
                        recyclerView.visibility = View.VISIBLE
                    }
                },
                onFailure = {
                    loadingView.visibility = View.GONE
                    emptyView.visibility = View.VISIBLE
                }
            )
        }
    }
}
